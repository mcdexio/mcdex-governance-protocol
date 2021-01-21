// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./BallotBox.sol";

abstract contract LockableBallotBox is BallotBox {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    mapping(address => uint256) public unlockBlocks;
    mapping(address => EnumerableSet.UintSet) internal _votedProposals;

    uint256 internal _delayAfterSucceeded;

    function __ShareLock_init(uint256 executionDelay, uint256 unlockDelay) internal initializer {
        __ShareLock_init_unchained(executionDelay, unlockDelay);
    }

    function __ShareLock_init_unchained(uint256 executionDelay, uint256 unlockDelay)
        internal
        initializer
    {
        _delayAfterSucceeded = executionDelay.add(unlockDelay);
    }

    function delayAfterSucceeded() public view returns (uint256) {
        return _delayAfterSucceeded;
    }

    function isLocked(address voter) public returns (bool) {
        updateLock(voter);
        return unlockBlocks[voter] > getBlockNumber();
    }

    // enum ProposalState {
    // ---------------------- ignore ----------------------
    //     Pending,         < startBlock
    //     Active,          < endBlock
    //
    // ---------------------- remove ----------------------
    //     Canceled,        < canceled
    //     Expired,         > now >= eta + grace
    //     Defeated,        < for <= against || for < quorum
    //
    // ---------------------- 72 + 48 H ----------------------
    //     Succeeded,       < eta == 0
    //     Executed         > proposal.executed
    //     Queued,
    // }
    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    ) internal virtual override {
        BallotBox._castVote(voter, proposalId, support);
        updateLock(voter);
        _votedProposals[voter].add(proposalId);
    }

    function updateLock(address voter) internal virtual {
        uint256 unlockBlock = unlockBlocks[voter];
        if (getBlockNumber() < unlockBlock) {
            return;
        }
        EnumerableSet.UintSet storage voted = _votedProposals[voter];
        uint256 length = voted.length();
        for (uint256 i = 0; i < length; i++) {
            uint256 proposalId = voted.at(i);
            ProposalState state = state(proposalId);
            if (state == ProposalState.Pending || state == ProposalState.Active) {
                i++;
                continue;
            }
            if (
                state == ProposalState.Succeeded ||
                state == ProposalState.Executed ||
                state == ProposalState.Queued
            ) {
                uint256 unlockBlock = proposals[proposalId].endBlock.add(_delayAfterSucceeded);
                if (unlockBlock > unlockBlocks[voter]) {
                    unlockBlocks[voter] = unlockBlock;
                }
            }
            voted.remove(proposalId);
        }
    }

    function getBlockNumber() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.number;
    }
}