// Project Structure:
// decentralized-crowdfunding-platform/
// ├── contracts/
// │   └── Project.sol
// ├── README.md
// └── package.json

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Crowdfunding Platform
 * @dev A transparent, trustless crowdfunding smart contract
 * @author Blockchain Developer
 */
contract Project {
    
    // Enum to track campaign status
    enum CampaignStatus { 
        ACTIVE, 
        SUCCESSFUL, 
        FAILED, 
        WITHDRAWN 
    }
    
    // Struct to define campaign details
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        CampaignStatus status;
        uint256 createdAt;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    // State variables
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public constant PLATFORM_FEE = 25; // 0.25% fee (25/10000)
    address public platformOwner;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );
    
    event CampaignSuccessful(
        uint256 indexed campaignId,
        uint256 totalRaised,
        address indexed creator
    );
    
    event RefundProcessed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    // Modifiers
    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Invalid campaign ID");
        _;
    }
    
    modifier onlyCreator(uint256 _campaignId) {
        require(
            msg.sender == campaigns[_campaignId].creator,
            "Only campaign creator can call this function"
        );
        _;
    }
    
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this");
        _;
    }
    
    constructor() {
        platformOwner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Title of the campaign
     * @param _description Description of what's being funded
     * @param _goalAmount Target amount to raise (in wei)
     * @param _durationInDays Duration of campaign in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");
        
        uint256 campaignId = campaignCounter++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        Campaign storage newCampaign = campaigns[campaignId];
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = deadline;
        newCampaign.status = CampaignStatus.ACTIVE;
        newCampaign.createdAt = block.timestamp;
        
        emit CampaignCreated(campaignId, msg.sender, _title, _goalAmount, deadline);
        
        return campaignId;
    }
    
    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) 
        external 
        payable 
        validCampaign(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(campaign.status == CampaignStatus.ACTIVE, "Campaign is not active");
        require(block.timestamp < campaign.deadline, "Campaign deadline has passed");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(msg.sender != campaign.creator, "Creator cannot contribute to own campaign");
        
        // Track new contributors
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        // Update contribution tracking
        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount) {
            campaign.status = CampaignStatus.SUCCESSFUL;
            emit CampaignSuccessful(_campaignId, campaign.raisedAmount, campaign.creator);
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value, campaign.raisedAmount);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds or get refund
     * @param _campaignId ID of the campaign
     */
    function processWithdrawalOrRefund(uint256 _campaignId) 
        external 
        validCampaign(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        // Check if campaign has ended
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        
        if (campaign.raisedAmount >= campaign.goalAmount && 
            campaign.status != CampaignStatus.WITHDRAWN) {
            // Campaign successful - creator can withdraw
            require(msg.sender == campaign.creator, "Only creator can withdraw successful funds");
            require(campaign.status == CampaignStatus.SUCCESSFUL, "Campaign not successful");
            
            campaign.status = CampaignStatus.WITHDRAWN;
            
            // Calculate platform fee and creator amount
            uint256 platformFee = (campaign.raisedAmount * PLATFORM_FEE) / 10000;
            uint256 creatorAmount = campaign.raisedAmount - platformFee;
            
            // Transfer funds
            campaign.creator.transfer(creatorAmount);
            payable(platformOwner).transfer(platformFee);
            
            emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
            
        } else {
            // Campaign failed - contributors can get refund
            require(campaign.contributions[msg.sender] > 0, "No contribution found");
            
            if (campaign.status == CampaignStatus.ACTIVE) {
                campaign.status = CampaignStatus.FAILED;
            }
            
            uint256 refundAmount = campaign.contributions[msg.sender];
            campaign.contributions[msg.sender] = 0;
            
            payable(msg.sender).transfer(refundAmount);
            
            emit RefundProcessed(_campaignId, msg.sender, refundAmount);
        }
    }
    
    // View functions
    function getCampaignDetails(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            CampaignStatus status,
            uint256 createdAt,
            uint256 contributorCount
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.status,
            campaign.createdAt,
            campaign.contributors.length
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        validCampaign(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getTotalCampaigns() external view returns (uint256) {
        return campaignCounter;
    }
    
    function getCampaignContributors(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (address[] memory)
    {
        return campaigns[_campaignId].contributors;
    }
    
    // Emergency function for platform owner
    function emergencyWithdraw() external onlyPlatformOwner {
        payable(platformOwner).transfer(address(this).balance);
    }
}
