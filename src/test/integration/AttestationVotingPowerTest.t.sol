// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {AttestationVotingPower} from "../../contracts/AttestationVotingPower.sol";
import {StudentVoting} from "../../contracts/StudentVoting.sol";
import {StudentRegistry} from "../../contracts/StudentRegistry.sol";
import {MockEAS} from "../mocks/MockEAS.sol";
import {IRegenStaker} from "../../interfaces/IRegenStaker.sol";

/**
 * @title MockRegenStaker
 * @notice Mock RegenStaker for testing
 */
contract MockRegenStaker is IRegenStaker {
    mapping(address => uint256) public depositorTotalEarningPower;

    function setEarningPower(address depositor, uint256 power) external {
        depositorTotalEarningPower[depositor] = power;
    }
}

/**
 * @title AttestationVotingPowerTest
 * @notice Tests for attestation-based voting power boosts
 */
contract AttestationVotingPowerTest is Test {
    MockEAS public eas;
    StudentRegistry public studentRegistry;
    AttestationVotingPower public attestationVotingPower;
    StudentVoting public studentVoting;
    MockRegenStaker public regenStaker;

    // Test addresses
    address public student1 = address(200);
    address public student2 = address(201);
    address public attester = address(300);

    // Test schema
    bytes32 public constant VALID_SCHEMA = keccak256("StudentAchievement");
    uint256 public constant BOOST_MULTIPLIER_BPS = 1000; // 10% per attestation
    uint256 public constant MAX_BOOST_BPS = 5000; // 50% max boost

    function setUp() public {
        // Deploy EAS mock
        eas = new MockEAS();
        vm.label(address(eas), "MockEAS");

        // Deploy StudentRegistry
        studentRegistry = new StudentRegistry();
        vm.label(address(studentRegistry), "StudentRegistry");

        // Deploy AttestationVotingPower
        attestationVotingPower = new AttestationVotingPower(
            address(eas),
            address(studentRegistry),
            VALID_SCHEMA,
            BOOST_MULTIPLIER_BPS,
            MAX_BOOST_BPS
        );
        vm.label(address(attestationVotingPower), "AttestationVotingPower");

        // Deploy MockRegenStaker
        regenStaker = new MockRegenStaker();
        vm.label(address(regenStaker), "MockRegenStaker");

        // Deploy StudentVoting
        studentVoting = new StudentVoting(address(regenStaker), address(studentRegistry));
        vm.label(address(studentVoting), "StudentVoting");

        // Set AttestationVotingPower in StudentVoting
        vm.prank(studentVoting.owner());
        studentVoting.setAttestationVotingPower(address(attestationVotingPower));

        // Add students
        vm.prank(studentRegistry.owner());
        studentRegistry.addStudent(student1, "Alice Chen", "MIT", "AI & Robotics");
        vm.prank(studentRegistry.owner());
        studentRegistry.addStudent(student2, "Bob Martinez", "Stanford", "Climate Science");

        // Set base earning power
        regenStaker.setEarningPower(student1, 10_000 * 1e18); // 10k tokens
        regenStaker.setEarningPower(student2, 5_000 * 1e18); // 5k tokens
    }

    /**
     * @notice Test submitting a valid attestation
     */
    function test_submitValidAttestation() public {
        // Create attestation
        vm.prank(attester);
        bytes32 attestationUID = eas.createAttestation(student1, VALID_SCHEMA, 0, "");

        // Student submits attestation
        vm.prank(student1);
        attestationVotingPower.submitAttestation(attestationUID);

        // Verify boost was applied
        uint256 boostBps = attestationVotingPower.getStudentBoostBps(student1);
        assertEq(boostBps, BOOST_MULTIPLIER_BPS, "Boost should be 10%");

        // Verify voting power increased
        uint256 basePower = regenStaker.depositorTotalEarningPower(student1);
        uint256 totalPower = studentVoting.getStudentVotingPower(student1);
        uint256 expectedBoost = (basePower * BOOST_MULTIPLIER_BPS) / 10_000;
        assertEq(totalPower, basePower + expectedBoost, "Total power should include boost");
    }

    /**
     * @notice Test multiple attestations up to max boost
     */
    function test_multipleAttestationsUpToMax() public {
        uint256 basePower = regenStaker.depositorTotalEarningPower(student1);

        // Submit 6 attestations (should cap at 50% = 5 attestations worth)
        for (uint256 i = 0; i < 6; i++) {
            vm.prank(attester);
            bytes32 uid = eas.createAttestation(student1, VALID_SCHEMA, 0, "");

            vm.prank(student1);
            attestationVotingPower.submitAttestation(uid);
        }

        // Should be capped at max boost
        uint256 boostBps = attestationVotingPower.getStudentBoostBps(student1);
        assertEq(boostBps, MAX_BOOST_BPS, "Should be capped at 50%");

        // Verify total power
        uint256 totalPower = studentVoting.getStudentVotingPower(student1);
        uint256 expectedBoost = (basePower * MAX_BOOST_BPS) / 10_000;
        assertEq(totalPower, basePower + expectedBoost, "Total power should be base + max boost");
    }

    /**
     * @notice Test attestation revocation
     */
    function test_attestationRevocation() public {
        // Create and submit attestation
        vm.prank(attester);
        bytes32 uid = eas.createAttestation(student1, VALID_SCHEMA, 0, "");

        vm.prank(student1);
        attestationVotingPower.submitAttestation(uid);

        // Verify boost exists
        assertGt(attestationVotingPower.getStudentBoostBps(student1), 0, "Should have boost");

        // Revoke attestation on EAS
        vm.prank(attester);
        eas.revokeAttestation(uid);

        // Revoke in AttestationVotingPower
        attestationVotingPower.revokeAttestation(student1, uid);

        // Verify boost removed
        assertEq(attestationVotingPower.getStudentBoostBps(student1), 0, "Boost should be removed");
    }

    /**
     * @notice Test invalid attestation (wrong schema)
     */
    function test_invalidSchema() public {
        bytes32 invalidSchema = keccak256("InvalidSchema");
        vm.prank(attester);
        bytes32 uid = eas.createAttestation(student1, invalidSchema, 0, "");

        vm.prank(student1);
        vm.expectRevert("Invalid schema");
        attestationVotingPower.submitAttestation(uid);
    }

    /**
     * @notice Test invalid attestation (wrong recipient)
     */
    function test_invalidRecipient() public {
        vm.prank(attester);
        bytes32 uid = eas.createAttestation(student2, VALID_SCHEMA, 0, "");

        vm.prank(student1);
        vm.expectRevert("Attestation recipient mismatch");
        attestationVotingPower.submitAttestation(uid);
    }

    /**
     * @notice Test expired attestation
     */
    function test_expiredAttestation() public {
        vm.prank(attester);
        bytes32 uid = eas.createAttestation(student1, VALID_SCHEMA, uint64(block.timestamp + 1 days), "");

        // Skip time past expiration
        skip(2 days);

        vm.prank(student1);
        vm.expectRevert("Attestation expired");
        attestationVotingPower.submitAttestation(uid);
    }

    /**
     * @notice Test voting power calculation with attestations
     */
    function test_votingPowerWithAttestations() public {
        uint256 basePower = 10_000 * 1e18;

        // Submit 2 attestations (20% boost)
        for (uint256 i = 0; i < 2; i++) {
            vm.prank(attester);
            bytes32 uid = eas.createAttestation(student1, VALID_SCHEMA, 0, "");

            vm.prank(student1);
            attestationVotingPower.submitAttestation(uid);
        }

        // Get voting power from StudentVoting
        uint256 totalPower = studentVoting.getStudentVotingPower(student1);
        uint256 expectedBoost = (basePower * 2000) / 10_000; // 20% boost
        assertEq(totalPower, basePower + expectedBoost, "Total power should include 20% boost");
    }
}

