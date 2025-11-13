// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGameVerifier.sol";
import "./Rewards.sol";
import "./CrossRealmNFT.sol";

contract Hub is Initializable, OwnableUpgradeable {
    struct Game {
        uint id;
        string gameType;
        uint stake;
        address token;
        address creator;
        address player2;
        bool isAI;
        bool isPrivate;
        address referral;
        bool zeroGas;
        bool active;
        string fen;
        address verifier;
        uint turn; // 0: creator, 1: player2/AI
    }

    mapping(uint => Game) public games;
    mapping(string => address) public verifiers;
    uint public gameCount;
    address payable public rewardsContract;
    address public nftContract;

    event GameCreated(uint id, address creator, string gameType, uint stake);
    event GameJoined(uint id, address player2);
    event MoveMade(uint id, string move, string newFen);
    event GameEnded(uint id, address winner, uint payout);

    function initialize(address _rewards, address _nft) public initializer {
        __Ownable_init(msg.sender);
        rewardsContract = payable(_rewards);
        nftContract = _nft;
    }

    function registerVerifier(string calldata _gameType, address _verifier) external onlyOwner {
        verifiers[_gameType] = _verifier;
    }

    function createGame(
        string memory _gameType,
        uint _stake,
        address _token,
        bool _isPrivate,
        address _referral,
        bool _isAI,
        bool _zeroGas,
        address _verifier
    ) external payable {
        require(_stake > 0, "Stake must be > 0");
        require(bytes(_gameType).length > 0, "Invalid game type");
        require(verifiers[_gameType] != address(0) || _verifier != address(0), "Verifier required");

        gameCount++;
        uint id = gameCount;
        address verifierAddr = _verifier != address(0) ? _verifier : verifiers[_gameType];

        uint potContribution = (_stake * 3) / 100;
        uint netStake = _stake - potContribution;
        if (_token == address(0)) {
            require(msg.value == _stake, "Incorrect ETH value");
            rewardsContract.transfer(potContribution);
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), netStake);
            if (potContribution > 0) {
                IERC20(_token).transferFrom(msg.sender, rewardsContract, potContribution);
            }
        }

        Rewards(rewardsContract).contributeToPot(potContribution, _token);

        games[id] = Game({
            id: id,
            gameType: _gameType,
            stake: netStake,
            token: _token,
            creator: msg.sender,
            player2: address(0),
            isAI: _isAI,
            isPrivate: _isPrivate,
            referral: _referral,
            zeroGas: _zeroGas,
            active: true,
            fen: _isAI ? getInitialFen(_gameType) : "",
            verifier: verifierAddr,
            turn: 0
        });

        emit GameCreated(id, msg.sender, _gameType, _stake);
    }

    function joinGame(uint _gameId) external payable {
        Game storage game = games[_gameId];
        require(game.active, "Game not active");
        require(game.player2 == address(0), "Game already joined");
        require(!game.isPrivate || game.creator == msg.sender || game.referral == msg.sender, "Private game access denied");
        require(game.stake > 0, "Invalid stake");

        uint potContribution = (game.stake * 3) / 100;
        uint netStake = game.stake - potContribution;

        if (game.token == address(0)) {
            require(msg.value == game.stake, "Incorrect ETH value");
            rewardsContract.transfer(potContribution);
        } else {
            IERC20(game.token).transferFrom(msg.sender, address(this), netStake);
            if (potContribution > 0) {
                IERC20(game.token).transferFrom(msg.sender, rewardsContract, potContribution);
            }
        }

        Rewards(rewardsContract).contributeToPot(potContribution, game.token);

        game.player2 = msg.sender;
        emit GameJoined(_gameId, msg.sender);
    }

    function makeMove(uint _gameId, string memory _move, string memory _newFen, bytes calldata _proof) external {
        Game storage game = games[_gameId];
        require(game.active, "Game not active");
        require(msg.sender == (game.turn == 0 ? game.creator : game.player2), "Not your turn");
        require(IGameVerifier(game.verifier).validateMove(_gameId, _move, keccak256(abi.encodePacked(game.fen)), keccak256(abi.encodePacked(_newFen))), "Invalid move");
        require(_proof.length == 0 || IGameVerifier(game.verifier).verifyProof(_gameId, _proof), "Invalid proof");

        game.fen = _newFen;
        game.turn = game.turn == 0 ? 1 : 0;

        emit MoveMade(_gameId, _move, _newFen);

        if (game.isAI && game.turn == 1) {
            // Stub for AI relay
        }
    }

    function settleMoveRelayer(uint _gameId, string memory _newFen) external onlyOwner {
        Game storage game = games[_gameId];
        require(game.active, "Game not active");
        game.fen = _newFen;
        game.turn = game.turn == 0 ? 1 : 0;
    }

    function endGame(uint _gameId, bool _creatorWins) external {
        Game storage game = games[_gameId];
        require(game.active, "Game not active");
        require(msg.sender == game.creator || msg.sender == game.player2 || msg.sender == owner(), "Unauthorized");

        game.active = false;
        address winner = _creatorWins ? game.creator : game.player2;
        uint payout = game.stake;

        if (game.token == address(0)) {
            payable(winner).transfer(payout);
        } else {
            IERC20(game.token).transfer(winner, payout);
        }

        Rewards(rewardsContract).incrementGamesPlayed(game.creator);
        Rewards(rewardsContract).incrementGamesPlayed(game.player2);

        if (!game.isAI) {
            CrossRealmNFT(nftContract).mintWinStreak(winner);
        }

        emit GameEnded(_gameId, winner, payout);
    }

    function getInitialFen(string memory _gameType) internal pure returns (string memory) {
        if (keccak256(abi.encodePacked(_gameType)) == keccak256(abi.encodePacked("chess"))) {
            return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
        } else if (keccak256(abi.encodePacked(_gameType)) == keccak256(abi.encodePacked("checkers"))) {
            return "WBDWB DWB WB DWB DWB WB DWB DWB:WHITE:8";
        }
        revert("Unsupported game type");
    }

    receive() external payable {}
}