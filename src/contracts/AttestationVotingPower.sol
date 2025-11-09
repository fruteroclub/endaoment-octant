// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEAS} from "../interfaces/IEAS.sol";
import {IStudentRegistry} from "../interfaces/IStudentRegistry.sol";

/**
 * @title AttestationVotingPower
 * @notice Manages attestation-based voting power boosts for students
 * @dev Verifies EAS attestations and grants voting power boosts to students
 *      Students can submit attestations (e.g., academic achievements, research publications)
 *      that boost their voting power beyond their staked amount
 */
contract AttestationVotingPower is Ownable {
    // EAS contract address
    IEAS public eas;

    // Student registry
    IStudentRegistry public studentRegistry;

    // Schema UID for valid attestations (must match EAS schema)
    bytes32 public validSchemaUID;

    // Attestation boost multiplier (in basis points, e.g., 1000 = 10% boost)
    uint256 public boostMultiplierBps;

    // Maximum boost cap (in basis points, e.g., 5000 = 50% max boost)
    uint256 public maxBoostBps;

    // Track submitted attestations per student
    // student => attestationUID => isVerified
    mapping(address => mapping(bytes32 => bool)) public verifiedAttestations;

    // Total attestation boost per student
    // student => totalBoost (in basis points)
    mapping(address => uint256) public studentAttestationBoosts;

    // Events
    event AttestationSubmitted(address indexed student, bytes32 indexed attestationUID);
    event AttestationVerified(address indexed student, bytes32 indexed attestationUID, uint256 boostBps);
    event AttestationRevoked(address indexed student, bytes32 indexed attestationUID);
    event BoostMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event MaxBoostUpdated(uint256 oldMax, uint256 newMax);
    event SchemaUIDUpdated(bytes32 oldSchema, bytes32 newSchema);

    /**
     * @notice Initialize AttestationVotingPower
     * @param _eas Address of EAS contract
     * @param _studentRegistry Address of StudentRegistry
     * @param _validSchemaUID Schema UID for valid attestations
     * @param _boostMultiplierBps Boost multiplier in basis points (e.g., 1000 = 10% per attestation)
     * @param _maxBoostBps Maximum boost cap in basis points (e.g., 5000 = 50% max)
     */
    constructor(
        address _eas,
        address _studentRegistry,
        bytes32 _validSchemaUID,
        uint256 _boostMultiplierBps,
        uint256 _maxBoostBps
    ) Ownable(msg.sender) {
        require(_eas != address(0), "Invalid EAS address");
        require(_studentRegistry != address(0), "Invalid StudentRegistry address");
        require(_boostMultiplierBps > 0, "Boost multiplier must be positive");
        require(_maxBoostBps >= _boostMultiplierBps, "Max boost must be >= multiplier");

        eas = IEAS(_eas);
        studentRegistry = IStudentRegistry(_studentRegistry);
        validSchemaUID = _validSchemaUID;
        boostMultiplierBps = _boostMultiplierBps;
        maxBoostBps = _maxBoostBps;
    }

    /**
     * @notice Submit an attestation for verification
     * @param attestationUID The UID of the EAS attestation
     * @dev Verifies the attestation and grants voting power boost if valid
     */
    function submitAttestation(bytes32 attestationUID) external {
        require(studentRegistry.isStudentActive(msg.sender), "Only active students can submit");
        require(!verifiedAttestations[msg.sender][attestationUID], "Attestation already verified");

        // Get attestation from EAS
        IEAS.Attestation memory attestation = eas.getAttestation(attestationUID);

        // Verify attestation is valid
        require(attestation.uid != bytes32(0), "Attestation does not exist");
        require(attestation.schema == validSchemaUID, "Invalid schema");
        require(attestation.recipient == msg.sender, "Attestation recipient mismatch");
        require(attestation.revocationTime == 0, "Attestation revoked");
        require(attestation.expirationTime == 0 || attestation.expirationTime > block.timestamp, "Attestation expired");

        // Mark as verified
        verifiedAttestations[msg.sender][attestationUID] = true;

        // Calculate and apply boost
        uint256 currentBoost = studentAttestationBoosts[msg.sender];
        uint256 newBoost = currentBoost + boostMultiplierBps;

        // Cap at maximum boost
        if (newBoost > maxBoostBps) {
            newBoost = maxBoostBps;
        }

        studentAttestationBoosts[msg.sender] = newBoost;

        emit AttestationSubmitted(msg.sender, attestationUID);
        emit AttestationVerified(msg.sender, attestationUID, boostMultiplierBps);
    }

    /**
     * @notice Revoke an attestation (if it was revoked on EAS)
     * @param student Student address
     * @param attestationUID The UID of the attestation to revoke
     * @dev Can be called by anyone to sync with EAS revocation status
     */
    function revokeAttestation(address student, bytes32 attestationUID) external {
        require(verifiedAttestations[student][attestationUID], "Attestation not verified");

        // Check if attestation was revoked on EAS
        IEAS.Attestation memory attestation = eas.getAttestation(attestationUID);
        require(attestation.revocationTime > 0, "Attestation not revoked on EAS");

        // Remove verification
        verifiedAttestations[student][attestationUID] = false;

        // Reduce boost
        uint256 currentBoost = studentAttestationBoosts[student];
        uint256 newBoost = currentBoost >= boostMultiplierBps ? currentBoost - boostMultiplierBps : 0;
        studentAttestationBoosts[student] = newBoost;

        emit AttestationRevoked(student, attestationUID);
    }

    /**
     * @notice Get attestation-based voting power boost for a student
     * @param student Student address
     * @param baseVotingPower Base voting power from RegenStaker
     * @return boostAmount The additional voting power from attestations
     * @return totalVotingPower Base + boost voting power
     */
    function getAttestationBoost(address student, uint256 baseVotingPower) external view returns (uint256 boostAmount, uint256 totalVotingPower) {
        uint256 boostBps = studentAttestationBoosts[student];
        boostAmount = (baseVotingPower * boostBps) / 10_000; // Convert basis points to amount
        totalVotingPower = baseVotingPower + boostAmount;
    }

    /**
     * @notice Get total attestation boost (in basis points) for a student
     * @param student Student address
     * @return boostBps Total boost in basis points
     */
    function getStudentBoostBps(address student) external view returns (uint256) {
        return studentAttestationBoosts[student];
    }

    /**
     * @notice Set boost multiplier (owner only)
     * @param _boostMultiplierBps New boost multiplier in basis points
     */
    function setBoostMultiplier(uint256 _boostMultiplierBps) external onlyOwner {
        require(_boostMultiplierBps > 0, "Boost multiplier must be positive");
        uint256 oldMultiplier = boostMultiplierBps;
        boostMultiplierBps = _boostMultiplierBps;
        emit BoostMultiplierUpdated(oldMultiplier, _boostMultiplierBps);
    }

    /**
     * @notice Set maximum boost cap (owner only)
     * @param _maxBoostBps New maximum boost in basis points
     */
    function setMaxBoost(uint256 _maxBoostBps) external onlyOwner {
        require(_maxBoostBps >= boostMultiplierBps, "Max boost must be >= multiplier");
        uint256 oldMax = maxBoostBps;
        maxBoostBps = _maxBoostBps;
        emit MaxBoostUpdated(oldMax, _maxBoostBps);
    }

    /**
     * @notice Set valid schema UID (owner only)
     * @param _validSchemaUID New schema UID
     */
    function setSchemaUID(bytes32 _validSchemaUID) external onlyOwner {
        bytes32 oldSchema = validSchemaUID;
        validSchemaUID = _validSchemaUID;
        emit SchemaUIDUpdated(oldSchema, _validSchemaUID);
    }
}

