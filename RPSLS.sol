
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract RPSLS {
    IERC20 public token;
    uint256 public constant STAKE_AMOUNT = 0.000001 ether;
    CommitReveal public commitReveal;
    TimeUnit public timeUnit;

    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numCommits = 0;
    uint public numRevealed = 0;

    uint public revealStartTime;
    uint256 public constant PLAYER_JOIN_TIMEOUT_SECONDS = 30; // Timeout if another player does not join (Handle only for minutes unit)
    uint256 public constant REVEAL_TIMEOUT_SECONDS = 40; // Timeout if a player does not reveal (Handle only for minutes unit)

    mapping(address => uint) public player_choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - Spock, 4 - Lizard
    mapping(address => bool) public player_not_committed;
    mapping(address => bool) public player_not_revealed;

    address[] public players;

    constructor(address _commitRevealAddress, address _timeUnitAddress, address _tokenAddress) {
        commitReveal = CommitReveal(_commitRevealAddress);
        timeUnit = TimeUnit(_timeUnitAddress);
        token = IERC20(_tokenAddress);
    }

    // function generateRandomInput(uint8 choice) public view returns (bytes32, bytes32) {
    //     require(choice < 5, "Invalid choice (must be 0-4)");

    //     // Generate 31 random bytes using keccak256 (pseudo-random)
    //     bytes32 randBytes = keccak256(abi.encodePacked(block.timestamp, msg.sender));

    //     // Clear the last byte to zero
    //     randBytes &= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
        
    //     // Add choice to the last byte
    //     bytes32 revealHash = randBytes | bytes32(uint256(choice)); 

    //     // Compute the commit hash (dataHash)
    //     bytes32 dataHash = keccak256(abi.encodePacked(revealHash));

    //     return (revealHash, dataHash);
    // }

    function addPlayer() public payable {
        require(numPlayer < 2, "Cannot join: Maximum players reached.");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Already joined.");
        }
        // เรียกใช้ approve อัตโนมัติให้ msg.sender อนุญาตให้ contract ถอนเงินได้
        token.approve(address(this), STAKE_AMOUNT);
        
        reward += STAKE_AMOUNT;
        player_not_committed[msg.sender] = true;
        player_not_revealed[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;

        if (numPlayer == 1) {
            timeUnit.setStartTime();
        } else if (numPlayer == 2) {
            timeUnit.setStartTime();
        }
    }

    function isPlayerinGame(address _player) public view returns (bool) {
        return (_player == players[0] || _player == players[1]);
    }

    function commitChoice(bytes32 dataHash) public {
        require(numPlayer == 2, "Need 2 players.");
        require(isPlayerinGame(msg.sender), "You are not a player in this game.");
        require(numRevealed == 0, "Can't change choice because someone has revealed.");
        commitReveal.commit(msg.sender, dataHash);
        if (player_not_committed[msg.sender]) {
            player_not_committed[msg.sender] = false;
            timeUnit.setStartTime();
            numCommits++;
        }
    }

    function revealChoice(bytes32 revealHash) public {
        require(numPlayer == 2, "Need 2 players.");
        require(isPlayerinGame(msg.sender), "You are not a player in this game.");
        require(numCommits == 2, "Both players have to committed");

        // Call reveal in CommitReveal.sol
        commitReveal.reveal(msg.sender, revealHash);

        // Extract choice from the last byte of revealHash
        uint choice = uint(uint8(revealHash[31]));
        player_choice[msg.sender] = choice;

        player_not_revealed[msg.sender] = false;
        numRevealed++;

        if (numRevealed == 2) {
            _checkWinnerAndPay();
        }
    }

    function refundIfNoOpponent() public {
        require(numPlayer == 1, "Can only withdraw if waiting for an opponent.");
        require(timeUnit.elapsedSeconds() >= PLAYER_JOIN_TIMEOUT_SECONDS, "Not Timeout Yet.");

        // Refund to only 1 player
        payable(players[0]).transfer(reward);

        resetGame();
    }

    function refundIfNoReveal() public {
        require(numPlayer == 2, "Game not started");
        require(numRevealed < 2, "Both players have revealed.");
        require(timeUnit.elapsedSeconds() >= REVEAL_TIMEOUT_SECONDS, "Reveal period not over yet.");

        // 2 players didn't reveal within the time, so refund both equally
        if (player_not_revealed[players[0]] && player_not_revealed[players[1]]) {
            payable(players[0]).transfer(reward / 2);
            payable(players[1]).transfer(reward / 2);
        } else if (player_not_revealed[players[0]]) {
            // Player 0 didn't reveal, so Player 1 will win.
            payable(players[1]).transfer(reward);
        } else {
            // Player 1 didn't reveal, so Player 0 will win.
            payable(players[0]).transfer(reward);
        }

        resetGame();
    }

    function isValidChoice(uint choice) public pure returns (bool) {
        return choice >= 0 && choice < 5;
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if (isValidChoice(p0Choice) && isValidChoice(p1Choice)) {
            // Winner logic for Rock, Paper, Scissors, Spock, and Lizard game
            if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
                // Player 1 won, so pay player[1]
                account1.transfer(reward);
            }
            else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
                // Player 0 won, so pay player[0]
                account0.transfer(reward);
            }
            else {
                // draw, so split reward
                account0.transfer(reward / 2);
                account1.transfer(reward / 2);
            }
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        resetGame();
    }

    function resetGame() private {
        for (uint i = 0; i < players.length; i++) {
            delete player_choice[players[i]];
            delete player_not_committed[players[i]];
            delete player_not_revealed[players[i]];
        }
        delete players;
        numPlayer = 0;
        reward = 0;
        numCommits = 0;
        numRevealed = 0;
    }
}