// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2ERC20.sol";
import "./PredictionMarket.sol";

/**
 * @title PredictionMarketVoting
 * @dev Allows LPs to vote on market resolutions during seeding phase
 */
contract PredictionMarketVoting {
    enum VoteChoice { YES, NO, POWER }
    
    struct Vote {
        VoteChoice choice;
        uint256 weight;
        uint256 timestamp;
    }
    
    struct VotingSession {
        uint256 startTime;
        uint256 endTime;
        uint256 totalVotingPower;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 powerVotes;
        bool resolved;
        VoteChoice result;
        mapping(address => Vote) votes;
        mapping(address => bool) hasVoted;
    }
    
    mapping(address => VotingSession) public votingSessions; // market address => voting session
    mapping(address => mapping(address => uint256)) public lpPower; // market => lp => power
    
    uint256 public constant VOTING_DURATION = 24 hours;
    uint256 public constant WITHDRAWAL_DURATION = 12 hours;
    
    event VotingStarted(address indexed market, uint256 startTime, uint256 endTime);
    event VoteCast(address indexed market, address indexed voter, VoteChoice choice, uint256 weight);
    event VotingResolved(address indexed market, VoteChoice result);
    event LPPowerRegistered(address indexed market, address indexed lp, uint256 power);
    
    /**
     * @dev Register LP voting power based on their liquidity provision
     */
    function registerLPPower(
        address market,
        address lp,
        address yesUsdcPair,
        address noUsdcPair
    ) external {
        uint256 yesLPBalance = IUniswapV2ERC20(yesUsdcPair).balanceOf(lp);
        uint256 noLPBalance = IUniswapV2ERC20(noUsdcPair).balanceOf(lp);
        
        uint256 totalPower = yesLPBalance + noLPBalance;
        require(totalPower > 0, "No LP tokens");
        
        lpPower[market][lp] = totalPower;
        votingSessions[market].totalVotingPower += totalPower;
        
        emit LPPowerRegistered(market, lp, totalPower);
    }
    
    /**
     * @dev Start voting session for a market
     */
    function startVoting(address market) external {
        VotingSession storage session = votingSessions[market];
        require(session.startTime == 0, "Voting already started");
        require(session.totalVotingPower > 0, "No voting power registered");
        
        session.startTime = block.timestamp;
        session.endTime = block.timestamp + VOTING_DURATION;
        
        emit VotingStarted(market, session.startTime, session.endTime);
    }
    
    /**
     * @dev Cast a vote on market resolution
     */
    function vote(address market, VoteChoice choice) external {
        VotingSession storage session = votingSessions[market];
        require(session.startTime > 0, "Voting not started");
        require(block.timestamp >= session.startTime, "Voting not started");
        require(block.timestamp <= session.endTime, "Voting ended");
        require(!session.hasVoted[msg.sender], "Already voted");
        
        uint256 voterPower = lpPower[market][msg.sender];
        require(voterPower > 0, "No voting power");
        
        session.votes[msg.sender] = Vote({
            choice: choice,
            weight: voterPower,
            timestamp: block.timestamp
        });
        
        session.hasVoted[msg.sender] = true;
        
        if (choice == VoteChoice.YES) {
            session.yesVotes += voterPower;
        } else if (choice == VoteChoice.NO) {
            session.noVotes += voterPower;
        } else {
            session.powerVotes += voterPower;
        }
        
        emit VoteCast(market, msg.sender, choice, voterPower);
    }
    
    /**
     * @dev Resolve voting and determine result
     */
    function resolveVoting(address market) external {
        VotingSession storage session = votingSessions[market];
        require(session.startTime > 0, "Voting not started");
        require(block.timestamp > session.endTime, "Voting still active");
        require(!session.resolved, "Already resolved");
        
        // Determine winner
        VoteChoice result;
        if (session.yesVotes >= session.noVotes && session.yesVotes >= session.powerVotes) {
            result = VoteChoice.YES;
        } else if (session.noVotes >= session.powerVotes) {
            result = VoteChoice.NO;
        } else {
            result = VoteChoice.POWER;
        }
        
        session.result = result;
        session.resolved = true;
        
        emit VotingResolved(market, result);
    }
    
    /**
     * @dev Check if LP can withdraw (voted differently than result)
     */
    function canWithdraw(address market, address lp) external view returns (bool) {
        VotingSession storage session = votingSessions[market];
        require(session.resolved, "Voting not resolved");
        require(block.timestamp <= session.endTime + WITHDRAWAL_DURATION, "Withdrawal period ended");
        
        if (!session.hasVoted[lp]) {
            return false; // Didn't vote, can't withdraw
        }
        
        return session.votes[lp].choice != session.result;
    }
    
    /**
     * @dev Get voting session info
     */
    function getVotingSession(address market) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 totalVotingPower,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 powerVotes,
        bool resolved,
        VoteChoice result
    ) {
        VotingSession storage session = votingSessions[market];
        return (
            session.startTime,
            session.endTime,
            session.totalVotingPower,
            session.yesVotes,
            session.noVotes,
            session.powerVotes,
            session.resolved,
            session.result
        );
    }
    
    /**
     * @dev Get LP's vote
     */
    function getLPVote(address market, address lp) external view returns (
        VoteChoice choice,
        uint256 weight,
        uint256 timestamp,
        bool hasVoted
    ) {
        VotingSession storage session = votingSessions[market];
        Vote storage lpVote = session.votes[lp];
        return (
            lpVote.choice,
            lpVote.weight,
            lpVote.timestamp,
            session.hasVoted[lp]
        );
    }
    
    /**
     * @dev Check if trading can begin
     */
    function canStartTrading(address market) external view returns (bool) {
        VotingSession storage session = votingSessions[market];
        return session.resolved && 
               block.timestamp > session.endTime + WITHDRAWAL_DURATION;
    }
} 