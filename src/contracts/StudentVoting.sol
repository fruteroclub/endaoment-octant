// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStudentRegistry} from "../interfaces/IStudentRegistry.sol";
import {IRegenStaker} from "../interfaces/IRegenStaker.sol";

/**
 * @title StudentVoting
 * @notice Manages student voting for proposals using RegenStaker earning power
 * @dev Students vote for proposals (other students) using their earning power from RegenStaker
 */
contract StudentVoting is Ownable {
    // RegenStaker contract
    IRegenStaker public regenStaker;

    // Student registry
    IStudentRegistry public studentRegistry;

    // AllocationManager address (can set epoch)
    address public allocationManager;

    // Student votes per epoch per proposal
    // epochId => voter => proposal => votes
    mapping(uint256 => mapping(address => mapping(address => uint256))) public studentVotes;

    // Total votes per proposal per epoch
    // epochId => proposal => totalVotes
    mapping(uint256 => mapping(address => uint256)) public proposalTotalVotes;

    // Total votes cast per epoch
    // epochId => totalVotes
    mapping(uint256 => uint256) public epochTotalVotes;

    // Current epoch ID (should match AllocationManager)
    uint256 public currentEpochId;

    // Events
    event StudentVoted(
        uint256 indexed epochId,
        address indexed voter,
        address indexed proposal,
        uint256 votingPower
    );
    event EpochSet(uint256 indexed epochId);

    /**
     * @notice Initialize StudentVoting
     * @param _regenStaker Address of RegenStaker contract
     * @param _studentRegistry Address of StudentRegistry contract
     */
    constructor(address _regenStaker, address _studentRegistry) Ownable(msg.sender) {
        require(_regenStaker != address(0), "Invalid RegenStaker address");
        require(_studentRegistry != address(0), "Invalid StudentRegistry address");

        regenStaker = IRegenStaker(_regenStaker);
        studentRegistry = IStudentRegistry(_studentRegistry);
    }

    /**
     * @notice Set the AllocationManager address (can set epoch)
     * @param _allocationManager Address of AllocationManager
     */
    function setAllocationManager(address _allocationManager) external onlyOwner {
        require(_allocationManager != address(0), "Invalid AllocationManager address");
        allocationManager = _allocationManager;
    }

    /**
     * @notice Set the current epoch ID (should be called by AllocationManager)
     * @param epochId New epoch ID
     */
    function setEpochId(uint256 epochId) external {
        require(msg.sender == allocationManager || msg.sender == owner(), "Not authorized");
        currentEpochId = epochId;
        emit EpochSet(epochId);
    }

    /**
     * @notice Get student's voting power from RegenStaker
     * @param student Student address
     * @return Voting power (earning power from RegenStaker)
     */
    function getStudentVotingPower(address student) public view returns (uint256) {
        require(studentRegistry.isStudentActive(student), "Student not active");
        return regenStaker.depositorTotalEarningPower(student);
    }

    /**
     * @notice Vote for a proposal (student) using earning power
     * @param proposal Address of proposal (student) to vote for
     * @param votingPower Amount of voting power to use (must be <= earning power)
     */
    function voteForProposal(address proposal, uint256 votingPower) external {
        require(studentRegistry.isStudentActive(msg.sender), "Only active students can vote");
        require(studentRegistry.isStudentActive(proposal), "Proposal must be active student");
        require(votingPower > 0, "Voting power must be positive");

        // Get student's available voting power
        uint256 availablePower = getStudentVotingPower(msg.sender);
        require(votingPower <= availablePower, "Insufficient voting power");

        // Get current votes for this voter-proposal pair
        uint256 previousVotes = studentVotes[currentEpochId][msg.sender][proposal];

        // Update vote tracking
        if (previousVotes > 0) {
            // Remove previous votes
            proposalTotalVotes[currentEpochId][proposal] -= previousVotes;
            epochTotalVotes[currentEpochId] -= previousVotes;
        }

        // Add new votes
        studentVotes[currentEpochId][msg.sender][proposal] = votingPower;
        proposalTotalVotes[currentEpochId][proposal] += votingPower;
        epochTotalVotes[currentEpochId] += votingPower;

        emit StudentVoted(currentEpochId, msg.sender, proposal, votingPower);
    }

    /**
     * @notice Get total votes for a proposal in current epoch
     * @param proposal Proposal address (student)
     * @return Total votes for the proposal
     */
    function getProposalVotes(address proposal) external view returns (uint256) {
        return proposalTotalVotes[currentEpochId][proposal];
    }

    /**
     * @notice Get votes for a proposal in a specific epoch
     * @param epochId Epoch ID
     * @param proposal Proposal address (student)
     * @return Total votes for the proposal
     */
    function getProposalVotesForEpoch(uint256 epochId, address proposal) external view returns (uint256) {
        return proposalTotalVotes[epochId][proposal];
    }

    /**
     * @notice Get student's votes for a proposal in current epoch
     * @param voter Student voter address
     * @param proposal Proposal address (student)
     * @return Votes cast by voter for proposal
     */
    function getStudentVotesForProposal(address voter, address proposal) external view returns (uint256) {
        return studentVotes[currentEpochId][voter][proposal];
    }
}

