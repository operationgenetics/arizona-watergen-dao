// SPDX-License-Identifier: AGPLv3-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/ArizonaWatergenDAO.sol";

contract MockOBSBindingCurve is IBindingCurveToken {
    uint256 public totalRaisedDAI = 0;

    function setTotalRaisedDAI(uint256 _raised) external {
        totalRaisedDAI = _raised;
    }
}

contract MockERC20Token is IERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }
}

contract ArizonaWatergenDAOTest is Test {
    ArizonaWatergenDAO public dao;
    MockOBSBindingCurve public bondingCurveMock;
    MockERC20Token public rewardToken;

    address constant MASTER_ADMIN = 0xBe53702c6f57aF155410f883f38f92414d39E3d5;
    address public roomieRobot = address(0x999);
    address public member1 = address(0x1);

    bytes public pqcPublicKey = hex"deadbeef1234567890abcdef";

    function setUp() public {
        bondingCurveMock = new MockOBSBindingCurve();
        rewardToken = new MockERC20Token();
        dao = new ArizonaWatergenDAO(address(bondingCurveMock));
    }

    function test_FullLifecycleAndSecurity() public {
        vm.prank(member1);
        dao.joinDAO();
        assertTrue(dao.getVotingPower(member1) == 100 * 10**18);

        vm.prank(member1);
        dao.createProposal("Deploy 50 atmospheric water generators in Tucson Sector", 7);

        assertFalse(dao.fundsUnlocked());
        bondingCurveMock.setTotalRaisedDAI(5_000_000_000 * 10**18);
        assertTrue(dao.checkAndUnlockFunds());
        assertTrue(dao.fundsUnlocked());

        vm.prank(MASTER_ADMIN);
        dao.setupRoomieRobotAndLock(roomieRobot, pqcPublicKey);
        assertTrue(dao.systemPermanentlyLocked());

        rewardToken.mint(address(dao), 10_000 * 10**18);

        uint256 nonce = dao.robotExecutionNonce();
        string memory missionLog = "Deploying solar water generator array";
        bytes32 messageHash = keccak256(abi.encodePacked(roomieRobot, address(rewardToken), member1, uint256(500 * 10**18), nonce, missionLog));
        bytes memory validSig = abi.encodePacked(messageHash, bytes32(uint256(1)));

        vm.prank(roomieRobot);
        dao.executeRobotOperationsWithPQC(address(rewardToken), member1, 500 * 10**18, nonce, missionLog, validSig);
        assertEq(rewardToken.balanceOf(member1), 500 * 10**18);

        uint256 watergenNonce = dao.robotExecutionNonce();
        string memory sectorTag = "Tucson Solar Watergen Hub #1";
        bytes32 watergenMsgHash = keccak256(abi.encodePacked(roomieRobot, uint256(5000), sectorTag, watergenNonce));
        bytes memory watergenSig = abi.encodePacked(watergenMsgHash, bytes32(uint256(1)));

        vm.prank(roomieRobot);
        dao.recordWatergenDeploymentWithPQC(5000, sectorTag, watergenNonce, watergenSig);
        assertEq(dao.totalWaterGeneratedLiters(), 5000);

        uint256 targetNonce = dao.robotExecutionNonce();
        uint256 targetIndex = 100000 * 10**18;
        bytes32 targetMsgHash = keccak256(abi.encodePacked(roomieRobot, targetIndex, targetNonce));
        bytes memory targetSig = abi.encodePacked(targetMsgHash, bytes32(uint256(1)));

        vm.prank(roomieRobot);
        dao.reportAndEnforceWatergenTarget(targetIndex, targetNonce, targetSig);
        assertTrue(dao.watergenTargetReached());
    }
}
