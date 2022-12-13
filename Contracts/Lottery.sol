// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "/home/jude_nix/Decentralized_Lottery/node_modules/@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "node_modules/@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "node_modules/@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
error Lottery__NotEnoughETHEntered();
error Lottery__TransferFailed();
error Lottery__NotOpen();
error Lottery__UpKeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 lotteryState);

/** @title A sample Lottery Contract
 * @author Jude Itopa
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements chainlink VRF v2 and Chainlink Keepers
 */
 abstract contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface  {
    /** State variables */
    enum LotteryState {
        OPEN,
        CALCULATING

    }
    address payable[] private s_players;
    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    //Lottery Variables
    address private s_recentWinner;
   // uint256 private s_state;
   LotteryState private s_lotteryState;
   uint256 private s_lastTimeStamp;
   uint256 private immutable i_interval;

    /*Events*/
    event LotteryEnter(address indexed player);
    event RequestedLotteryWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2, 
        uint256 entranceFee, 
        bytes32 gasLane,
        uint64 subcriptionId,
        uint32 callbackGasLimit,
        uint256  interval
        ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subcriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterLottery() public payable {
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughETHEntered();
        }
        if (s_lotteryState != LotteryState.OPEN)
           revert Lottery__NotOpen();
        s_players.push(payable(msg.sender));
        emit LotteryEnter(msg.sender);
    }
    /**
     * @dev This is the function that the Chainlink keeper nodes call
     * they look for the `upkeepNeeded` to return true
     * The following should be true in order to return true:
     * 1. Our time interval should have passed
     * 2. The lottery should have at least 1 player, and have some ETH
     * 3. Our subscription is funded with LINK
     * 4. The lottery should be in an `open` state
     */
    function checkUpkeep(
        bytes memory
        ) public override returns (bool upkeepNeeded, bytes memory)  {
            bool isOpen = (LotteryState.OPEN == s_lotteryState);
            bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
            bool hasPlayers = (s_players.length > 0);
            bool hasBalance = address(this).balance > 0;
            upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
            //block.timestamp - last block timestamp
        }
    function performUpKeep(bytes calldata) external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded){
            revert Lottery__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_lotteryState));
        }
       s_lotteryState = LotteryState.CALCULATING;
       
       uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedLotteryWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) 
    internal 
    override 
    {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_lotteryState = LotteryState.OPEN;
        /**Reseting the players array */
        s_players = new address payable[] (0);
        /**Reseting the timestamp */
        s_lastTimeStamp = block.timestamp;
        
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
         emit WinnerPicked(recentWinner);
    }
    /** view / Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLotteryState() public view returns (LotteryState){
        return s_lotteryState;
    }

    function getNumWords() public view returns(uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns(uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns(uint256){
        return REQUEST_CONFIRMATIONS;
    }
}
