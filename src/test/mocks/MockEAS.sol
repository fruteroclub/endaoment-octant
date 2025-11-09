// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IEAS} from "../../interfaces/IEAS.sol";

/**
 * @title MockEAS
 * @notice Mock implementation of EAS for testing
 * @dev Allows creating and managing attestations for testing purposes
 */
contract MockEAS is IEAS {
    // Mapping of UID to attestation
    mapping(bytes32 => Attestation) public attestations;

    // Counter for generating UIDs
    uint256 private _uidCounter;

    // Events
    event AttestationCreated(bytes32 indexed uid, address indexed recipient, bytes32 indexed schema);

    /**
     * @notice Create a mock attestation
     * @param recipient Recipient address
     * @param schema Schema UID
     * @param expirationTime Expiration timestamp (0 for no expiration)
     * @param data Custom attestation data
     * @return uid The UID of the created attestation
     */
    function createAttestation(
        address recipient,
        bytes32 schema,
        uint64 expirationTime,
        bytes memory data
    ) external returns (bytes32 uid) {
        uid = keccak256(abi.encodePacked(_uidCounter++, block.timestamp, recipient, schema));
        
        attestations[uid] = Attestation({
            uid: uid,
            schema: schema,
            time: uint64(block.timestamp),
            expirationTime: expirationTime,
            revocationTime: 0,
            refUID: bytes32(0),
            recipient: recipient,
            attester: msg.sender,
            revocable: true,
            data: data
        });

        emit AttestationCreated(uid, recipient, schema);
        return uid;
    }

    /**
     * @notice Revoke an attestation
     * @param uid Attestation UID
     */
    function revokeAttestation(bytes32 uid) external {
        require(attestations[uid].uid != bytes32(0), "Attestation does not exist");
        require(attestations[uid].revocationTime == 0, "Already revoked");
        attestations[uid].revocationTime = uint64(block.timestamp);
    }

    /**
     * @notice Get an attestation by its UID
     * @param uid The unique identifier of the attestation
     * @return The attestation data
     */
    function getAttestation(bytes32 uid) external view override returns (Attestation memory) {
        return attestations[uid];
    }
}

