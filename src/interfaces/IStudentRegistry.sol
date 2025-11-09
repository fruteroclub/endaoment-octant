// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IStudentRegistry
 * @notice Interface for StudentRegistry contract
 */
interface IStudentRegistry {
    struct Student {
        address wallet;
        string name;
        string university;
        string researchArea;
        bool isActive;
        uint256 totalReceived;
        uint256 addedAt;
    }

    function addStudent(
        address studentAddress,
        string calldata name,
        string calldata university,
        string calldata researchArea
    ) external;

    function getStudent(address studentAddress) external view returns (Student memory);

    function getAllStudents() external view returns (address[] memory);

    function getActiveStudents() external view returns (address[] memory);

    function isStudentActive(address studentAddress) external view returns (bool);

    function recordFunding(address studentAddress, uint256 amount) external;
}

