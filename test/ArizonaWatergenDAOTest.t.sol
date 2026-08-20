// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/ArizonaWatergenDAO.sol";

contract MockDAI is IERC20 {
    mapping(address => uint256) public balances;
    function transfer(address recipient, uint256 amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        balances[sender] -= amount;
        balances[recipient] += amount;
        return true;
    }
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    function mint(address account, uint256 amount) external {
        balances[account] += amount;
    }
}

contract ArizonaWatergenDAOTest is Test {
    ArizonaWatergenDAO dao;
    MockDAI dai;
    address admin = address(0x1);
    address user = address(0x2);

    function setUp() public {
        dai = new MockDAI();
        dao = new ArizonaWatergenDAO(address(dai), admin);
    }

    function test_DeploymentAndConstants() public {
        assertEq(dao.OBS_TOKEN_ADDRESS(), 0x2D8760e2877148d239a54952A458710553B2B54b);
        assertEq(dao.DESIGNATED_UPDATE_WALLET(), 0xaF570ce3b32D765b1236635B0f541a7487A1fB8e);
        assertFalse(dao.isImmutable());
    }

    function test_JoinAndMonthlyLP() public {
        vm.prank(user);
        dao.joinDAO();
        assertEq(dao.getEffectiveLPBalance(user), 100 * 1e18);
    }

    function test_ProposalCreationAndVoting() public {
        vm.startPrank(user);
        dao.joinDAO();
        
        dao.createProposal("Deploy Atmospheric Water Generator Array", 3);
        
        // 50 LP spent for proposal, leaving 50 LP to vote
        assertEq(dao.getEffectiveLPBalance(user), 50 * 1e18);

        dao.vote(1, true);
        vm.stopPrank();

        (uint256 id, address proposer, string memory desc, uint256 forVotes, uint256 againstVotes, uint256 deadline, uint256 costPaid, bool executed) = dao.proposals(1);
        assertEq(forVotes, 50 * 1e18);
        assertEq(againstVotes, 0);
        assertFalse(executed);
    }
}
