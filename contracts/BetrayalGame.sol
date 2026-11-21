// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BetrayalGame（背叛者悖论）
/// @notice 5 人各交押金 S，赞助方配资 100%（再出 5S），奖池 = 10S。
///         共 5 轮，每轮 commit-reveal：
///         0 人背叛 → 奖池滚入下一轮；5 轮全合作 → 玩家平分；
///         恰好 1 人背叛 → 该玩家拿走全部奖池，游戏结束；
///         2 人及以上背叛 → 全部奖池归赞助方，游戏结束。
contract BetrayalGame {
    uint8 public constant COOPERATE = 0;
    uint8 public constant BETRAY = 1;

    enum Phase { Lobby, Commit, Reveal, Ended }

    struct Room {
        address host;
        address sponsor;
        uint256 stake;
        uint8 maxPlayers;
        uint8 rounds;
        uint64 commitSecs;
        uint64 revealSecs;
        uint8 currentRound;
        Phase phase;
        uint64 phaseDeadline;
        uint256 pot;
        uint256 sponsorMatch;
        address[] players;
        bool started;
        address winner;
        uint8 endReason; // 1=单人背叛赢, 2=赞助方赢, 3=全合作平分
        uint256 lastPayout;
    }

    uint256 public nextRoomId;
    mapping(uint256 => Room) private rooms;

    mapping(uint256 => mapping(uint8 => mapping(address => bytes32))) private commitments;
    mapping(uint256 => mapping(uint8 => mapping(address => uint8))) private choices;
    mapping(uint256 => mapping(uint8 => mapping(address => bool))) private revealed;
    mapping(uint256 => mapping(address => bool)) private forfeited;

    event RoomCreated(uint256 indexed roomId, address indexed host, uint8 maxPlayers, uint256 stake, uint8 rounds);
    event Joined(uint256 indexed roomId, address indexed player);
    event Sponsored(uint256 indexed roomId, address indexed sponsor, uint256 amount);
    event GameStarted(uint256 indexed roomId);
    event Committed(uint256 indexed roomId, uint8 indexed round, address indexed player);
    event Revealed(uint256 indexed roomId, uint8 indexed round, address indexed player, uint8 choice);
    event RoundSettled(uint256 indexed roomId, uint8 indexed round, uint8 betrayers, uint256 pot);
    event GameEnded(uint256 indexed roomId, address indexed winner, uint256 amount, uint8 reason);

    modifier validRoom(uint256 id) {
        require(id < nextRoomId, "no room");
        _;
    }

    function createRoom(
        uint8 maxPlayers,
        uint8 rounds,
        uint64 commitSecs,
        uint64 revealSecs,
        uint256 stake
    ) external returns (uint256) {
        require(maxPlayers >= 3 && maxPlayers <= 10, "players 3-10");
        require(rounds >= 1 && rounds <= 10, "rounds 1-10");
        require(commitSecs > 0 && revealSecs > 0, "timing > 0");
        require(stake > 0, "stake > 0");
        uint256 id = nextRoomId++;
        Room storage r = rooms[id];
        r.host = msg.sender;
        r.maxPlayers = maxPlayers;
        r.rounds = rounds;
        r.commitSecs = commitSecs;
        r.revealSecs = revealSecs;
        r.stake = stake;
        r.phase = Phase.Lobby;
        emit RoomCreated(id, msg.sender, maxPlayers, stake, rounds);
        return id;
    }

    function joinRoom(uint256 id) external payable validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Lobby, "not lobby");
        require(r.players.length < r.maxPlayers, "full");
        require(msg.value == r.stake, "wrong stake");
        require(!_isPlayer(r, msg.sender), "joined");
        r.players.push(msg.sender);
        r.pot += msg.value;
        emit Joined(id, msg.sender);
    }

    function sponsorRoom(uint256 id) external payable validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Lobby, "not lobby");
        require(r.players.length == r.maxPlayers, "not full");
        require(r.sponsor == address(0), "sponsored");
        uint256 matchAmt = uint256(r.stake) * r.maxPlayers;
        require(msg.value == matchAmt, "wrong match");
        r.sponsor = msg.sender;
        r.sponsorMatch = msg.value;
        r.pot += msg.value;
        emit Sponsored(id, msg.sender, msg.value);
    }

    function startGame(uint256 id) external validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Lobby, "not lobby");
        require(r.players.length == r.maxPlayers, "not full");
        require(r.sponsor != address(0), "need sponsor");
        r.currentRound = 1;
        r.phase = Phase.Commit;
        r.phaseDeadline = uint64(block.timestamp) + r.commitSecs;
        r.started = true;
        emit GameStarted(id);
    }

    function beginReveal(uint256 id) external validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Commit, "not commit");
        require(block.timestamp >= r.phaseDeadline, "commit not over");
        r.phase = Phase.Reveal;
        r.phaseDeadline = uint64(block.timestamp) + r.revealSecs;
    }

    function commit(uint256 id, bytes32 commitment) external validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Commit, "not commit");
        require(r.currentRound >= 1 && r.currentRound <= r.rounds, "bad round");
        require(_isPlayer(r, msg.sender), "not player");
        require(commitments[id][r.currentRound][msg.sender] == bytes32(0), "committed");
        commitments[id][r.currentRound][msg.sender] = commitment;
        emit Committed(id, r.currentRound, msg.sender);
    }

    function reveal(uint256 id, address player, uint8 choice, bytes32 salt) external validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Reveal, "not reveal");
        require(choice == COOPERATE || choice == BETRAY, "bad choice");
        require(_isPlayer(r, player), "not player");
        require(!revealed[id][r.currentRound][player], "revealed");
        bytes32 c = commitments[id][r.currentRound][player];
        require(c != bytes32(0), "commit first");
        require(
            hashCommitment(choice, salt, player, id, r.currentRound) == c,
            "bad reveal"
        );
        revealed[id][r.currentRound][player] = true;
        choices[id][r.currentRound][player] = choice;
        emit Revealed(id, r.currentRound, player, choice);
    }

    function settleRound(uint256 id) external validRoom(id) {
        Room storage r = rooms[id];
        require(r.phase == Phase.Reveal, "not reveal");
        require(block.timestamp >= r.phaseDeadline, "reveal not over");

        uint8 betrayers = 0;
        for (uint256 i = 0; i < r.players.length; i++) {
            address p = r.players[i];
            if (revealed[id][r.currentRound][p]) {
                if (choices[id][r.currentRound][p] == BETRAY) betrayers++;
            } else {
                forfeited[id][p] = true;
            }
        }

        emit RoundSettled(id, r.currentRound, betrayers, r.pot);

        if (betrayers == 1) {
            address winner;
            for (uint256 i = 0; i < r.players.length; i++) {
                address p = r.players[i];
                if (revealed[id][r.currentRound][p] && choices[id][r.currentRound][p] == BETRAY) {
                    winner = p;
                    break;
                }
            }
            _endAndPay(id, winner, r.pot, 1);
        } else if (betrayers >= 2) {
            _endAndPay(id, r.sponsor, r.pot, 2);
        } else {
            if (r.currentRound == r.rounds) {
                _splitAndEnd(id);
            } else {
                r.currentRound++;
                r.phase = Phase.Commit;
                r.phaseDeadline = uint64(block.timestamp) + r.commitSecs;
            }
        }
    }

    function _endAndPay(uint256 id, address to, uint256 amount, uint8 reason) internal {
        Room storage r = rooms[id];
        r.phase = Phase.Ended;
        r.pot = 0;
        r.winner = to;
        r.endReason = reason;
        r.lastPayout = amount;
        _send(to, amount);
        emit GameEnded(id, to, amount, reason);
    }

    function _splitAndEnd(uint256 id) internal {
        Room storage r = rooms[id];
        uint256 eligibleCount = 0;
        for (uint256 i = 0; i < r.players.length; i++) {
            if (!forfeited[id][r.players[i]]) eligibleCount++;
        }
        if (eligibleCount == 0) {
            eligibleCount = r.players.length;
            for (uint256 i = 0; i < r.players.length; i++) forfeited[id][r.players[i]] = false;
        }
        uint256 per = r.pot / eligibleCount;
        uint256 remainder = r.pot - per * eligibleCount;
        for (uint256 i = 0; i < r.players.length; i++) {
            address p = r.players[i];
            if (!forfeited[id][p]) _send(p, per);
        }
        r.pot = 0;
        r.phase = Phase.Ended;
        r.endReason = 3;
        r.lastPayout = per;
        if (remainder > 0) _send(r.players[0], remainder);
        emit GameEnded(id, address(0), per, 3);
    }

    function _send(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "transfer failed");
    }

    /// @notice 前端用它算 commit 哈希，保证和合约里一致（避免 JS/Solidity 编码差异）
    function hashCommitment(
        uint8 choice,
        bytes32 salt,
        address player,
        uint256 roomId,
        uint8 round
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, salt, player, roomId, round));
    }

    function _isPlayer(Room storage r, address a) internal view returns (bool) {
        for (uint256 i = 0; i < r.players.length; i++) {
            if (r.players[i] == a) return true;
        }
        return false;
    }

    // ---------- 视图 ----------

    struct RoomView {
        address host;
        address sponsor;
        uint256 stake;
        uint8 maxPlayers;
        uint8 rounds;
        uint64 commitSecs;
        uint64 revealSecs;
        uint8 currentRound;
        uint8 phase;
        uint64 phaseDeadline;
        uint256 pot;
        uint256 sponsorMatch;
        bool started;
        address winner;
        uint8 endReason;
        uint256 lastPayout;
    }

    function roomInfo(uint256 id) external view returns (RoomView memory) {
        Room storage r = rooms[id];
        return
            RoomView({
                host: r.host,
                sponsor: r.sponsor,
                stake: r.stake,
                maxPlayers: r.maxPlayers,
                rounds: r.rounds,
                commitSecs: r.commitSecs,
                revealSecs: r.revealSecs,
                currentRound: r.currentRound,
                phase: uint8(r.phase),
                phaseDeadline: r.phaseDeadline,
                pot: r.pot,
                sponsorMatch: r.sponsorMatch,
                started: r.started,
                winner: r.winner,
                endReason: r.endReason,
                lastPayout: r.lastPayout
            });
    }

    function playersOf(uint256 id) external view returns (address[] memory) {
        return rooms[id].players;
    }

    function commitmentOf(uint256 id, uint8 round, address p) external view returns (bytes32) {
        return commitments[id][round][p];
    }

    function choiceOf(uint256 id, uint8 round, address p) external view returns (uint8) {
        return choices[id][round][p];
    }

    function isRevealed(uint256 id, uint8 round, address p) external view returns (bool) {
        return revealed[id][round][p];
    }

    function isForfeited(uint256 id, address p) external view returns (bool) {
        return forfeited[id][p];
    }
}
