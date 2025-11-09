// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title IEAS
 * @notice Interface for Ethereum Attestation Service (EAS)
 * @dev Simplified interface for verifying attestations
 */
interface IEAS {
    /**
     * @notice Get an attestation by its UID
     * @param uid The unique identifier of the attestation
     * @return The attestation data
     */
    function getAttestation(bytes32 uid) external view returns (Attestation memory);

    /**
     * @notice Attestation data structure
     */
    struct Attestation {
        bytes32 uid; // Unique identifier of the attestation
        bytes32 schema; // The identifier of the schema this attestation adheres to
        uint64 time; // The time when the attestation was created (Unix timestamp)
        uint64 expirationTime; // The time when the attestation expires (Unix timestamp)
        uint64 revocationTime; // The time when the attestation was revoked (Unix timestamp)
        bytes32 refUID; // The UID of the related attestation
        address recipient; // The recipient of the attestation
        address attester; // The attester/sender of the attestation
        bool revocable; // Whether the attestation is revocable
        bytes data; // Custom attestation data
    }
}

/**
 * @title ISchemaRegistry
 * @notice Interface for EAS Schema Registry
 */
interface ISchemaRegistry {
    /**
     * @notice Get schema information
     * @param uid The unique identifier of the schema
     * @return schema The schema data
     */
    function getSchema(bytes32 uid) external view returns (Schema memory);

    /**
     * @notice Schema data structure
     */
    struct Schema {
        bytes32 uid; // The unique identifier of the schema
        string schema; // The schema string
        address resolver; // Optional schema resolver
        bool revocable; // Whether attestations of this schema are revocable
    }
}

