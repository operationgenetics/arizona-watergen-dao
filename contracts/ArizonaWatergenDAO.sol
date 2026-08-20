// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract ArizonaWatergenDAO {
    uint256 public constant THRESHOLD_DAI = 5_000_000_000 * 1e18;
    address public constant OBS_TOKEN_ADDRESS = 0x2D8760e2877148d239a54952A458710553B2B54b;
    address public constant DESIGNATED_UPDATE_WALLET = 0xaF570ce3b32D765b1236635B0f541a7487A1fB8e;

    IERC20 public immutable arbitrumDAI;
    address public updateWallet;
    address public adminAddress;
    address public roomieBot;
    bytes public roomiePqcPublicKey;

    string public constant DAO_MISSION = "Autonomous robotic agents must actively deploy off-grid solar-powered atmospheric water generators and smart utility arrays, maintain regional soil humidity and green infrastructure, and enforce continuous on-chain validation until the water generation index reaches target capacity. GENERATED WATER AND INFRASTRUCTURE CAN NEVER BE USED FOR PRIVATE COMMERCIAL PROFIT; they are strictly dedicated to ecological restoration, off-grid resilience, and non-commercial DAO member support.";
    
    string public pqcAlgorithmSuite = "Hybrid Falcon-512 / Dilithium3 + ECDSA secp256k1 with Biometric Template Binding";
    bool public isImmutable = false;

    struct MemberLPInfo {
        uint256 balance;
        uint256 lastIssuanceMonth;
    }

    mapping(address => MemberLPInfo) public memberLP;
    mapping(address => bool) public members;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        uint256 costPaid;
        bool executed;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVotedOnProposal;

    event MemberJoined(address indexed member, uint256 timestamp);
    event LPtokensIssued(address indexed member, uint256 month, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, uint256 deadline, uint256 costPaid);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event RoomieRobotLinkedAndLocked(address indexed updateWallet, address indexed roomieRobot, bytes pqcPublicKey);
    event PermissionsRevoked(address indexed updateWallet);

    modifier onlyUpdateWallet() {
        require(msg.sender == updateWallet && msg.sender == DESIGNATED_UPDATE_WALLET, "Unauthorized: Only designated update wallet");
        require(!isImmutable, "Contract state is immutable");
        _;
    }

    constructor(address _arbitrumDAI, address _adminAddress) {
        arbitrumDAI = IERC20(_arbitrumDAI);
        updateWallet = DESIGNATED_UPDATE_WALLET;
        adminAddress = _adminAddress;
    }

    function joinDAO() external {
        require(!members[msg.sender], "Already a member");
        members[msg.sender] = true;
        emit MemberJoined(msg.sender, block.timestamp);
        _claimMonthlyLP(msg.sender);
    }

    function _getCurrentMonth() public view returns (uint256) {
        uint256 year = (block.timestamp / 31536000) + 1970;
        uint256 month = ((block.timestamp % 31536000) / 2628000) + 1;
        return (year * 100) + month;
    }

    function getEffectiveLPBalance(address member) public view returns (uint256) {
        MemberLPInfo memory info = memberLP[member];
        if (info.lastIssuanceMonth < _getCurrentMonth()) {
            return 0; // Expired at the end of the month
        }
        return info.balance;
    }

    function claimMonthlyLP() external {
        require(members[msg.sender], "Not a DAO member");
        _claimMonthlyLP(msg.sender);
    }

    function _claimMonthlyLP(address member) internal {
        uint256 currentMonth = _getCurrentMonth();
        MemberLPInfo storage info = memberLP[member];
        require(info.lastIssuanceMonth < currentMonth, "Already claimed for this month");
        info.balance = 100 * 1e18;
        info.lastIssuanceMonth = currentMonth;
        emit LPtokensIssued(member, currentMonth, 100 * 1e18);
    }

    function createProposal(string memory description, uint256 durationDays) external {
        require(members[msg.sender], "Only members");
        
        uint256 lpBal = getEffectiveLPBalance(msg.sender);
        require(lpBal >= 50 * 1e18, "Insufficient active monthly LP tokens: 50 required");
        
        // Deduct 50 LP for proposal creation
        memberLP[msg.sender].balance -= 50 * 1e18;

        uint256 proposalId = ++proposalCount;
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + (durationDays * 1 days),
            costPaid: 50 * 1e18,
            executed: false
        });

        emit ProposalCreated(proposalId, msg.sender, description, proposals[proposalId].deadline, 50 * 1e18);
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp < p.deadline, "Voting period ended");
        require(!p.executed, "Proposal already executed");
        require(!hasVotedOnProposal[proposalId][msg.sender], "Already voted");
        
        uint256 weight = getEffectiveLPBalance(msg.sender);
        require(weight > 0, "No active voting weight or tokens expired");

        hasVotedOnProposal[proposalId][msg.sender] = true;

        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function checkFundsUnlocked() public view returns (bool) {
        return arbitrumDAI.balanceOf(OBS_TOKEN_ADDRESS) >= THRESHOLD_DAI;
    }

    function setupRoomieRobotAndLock(address roomieRobotAddress, bytes calldata _pqcPublicKey) external onlyUpdateWallet {
        require(checkFundsUnlocked(), "Treasury locked: 5B DAI bonding curve threshold not met");
        require(roomieRobotAddress != address(0), "Invalid robot address");
        require(_pqcPublicKey.length > 0, "Invalid PQC public key");

        roomieBot = roomieRobotAddress;
        roomiePqcPublicKey = _pqcPublicKey;

        emit RoomieRobotLinkedAndLocked(updateWallet, roomieRobotAddress, _pqcPublicKey);
    }

    function revokeAndUpdatePermissions() external onlyUpdateWallet {
        isImmutable = true;
        updateWallet = address(0);
        emit PermissionsRevoked(msg.sender);
    }

    receive() external payable {}
}
