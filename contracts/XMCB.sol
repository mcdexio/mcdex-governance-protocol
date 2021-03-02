// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./libraries/SafeOwnable.sol";
import "./Comp.sol";
import "./BalanceBroadcaster.sol";

contract XMCB is Initializable, ContextUpgradeable, SafeOwnable, Comp, BalanceBroadcaster {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private constant WONE = 1e18;

    uint96 internal _rawTotalSupply;

    IERC20Upgradeable public rawToken;
    uint256 public withdrawalPenaltyRate;

    event Depoist(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount, uint256 penalty);
    event SetWithdrawalPenaltyRate(uint256 previousPenaltyRate, uint256 newPenaltyRate);

    function initialize(
        address owner_,
        address rawToken_,
        uint256 withdrawalPenaltyRate_
    ) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __Comp_init_unchained();
        __BalanceBroadcaster_init_unchained();

        rawToken = IERC20Upgradeable(rawToken_);
        withdrawalPenaltyRate = withdrawalPenaltyRate_;
        transferOwnership(owner_);
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _wmul(_balances[account], _balanceFactor());
    }

    function rawBalanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function rawTotalSupply() public view virtual returns (uint256) {
        return uint256(_rawTotalSupply);
    }

    function setWithdrawalPenaltyRate(uint256 withdrawalPenaltyRate_) public virtual onlyOwner {
        require(withdrawalPenaltyRate_ <= WONE, "new withdrawalPenaltyRate exceed 100%");
        emit SetWithdrawalPenaltyRate(withdrawalPenaltyRate, withdrawalPenaltyRate_);
        withdrawalPenaltyRate = withdrawalPenaltyRate_;
    }

    function deposit(uint256 amount) public virtual {
        require(amount > 0, "zero amount");
        _beforeMintingToken(_msgSender(), amount, _totalSupply);
        _deposit(_msgSender(), amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount != 0, "zero amount");
        require(amount <= balanceOf(_msgSender()), "exceeded withdrawable balance");
        _beforeBurningToken(_msgSender(), amount, _totalSupply);
        _withdraw(_msgSender(), amount);
    }

    function _deposit(address account, uint256 amount) internal virtual {
        rawToken.safeTransferFrom(account, address(this), amount);
        _mintRaw(account, _wdiv(amount, _balanceFactor()));
        _totalSupply = add96(
            _totalSupply,
            safe96(amount, "XMCB::_deposit: amount exceeds 96 bits"),
            "XMCB::_deposit: deposit amount overflows"
        );
        emit Depoist(account, amount);
    }

    function _withdraw(address account, uint256 amount) internal virtual {
        uint256 penalty = (amount == _totalSupply) ? 0 : _wmul(amount, withdrawalPenaltyRate);
        rawToken.safeTransfer(account, amount.sub(penalty));
        _burnRaw(account, _wdiv(amount, _balanceFactor()));
        _totalSupply = sub96(
            _totalSupply,
            safe96(amount.sub(penalty), "XMCB::_withdraw: amount exceeds 96 bits"),
            "XMCB::_withdraw: withdraw amount underflows"
        );
        emit Withdraw(account, amount, penalty);
    }

    function _mintRaw(address account, uint256 amount) internal virtual {
        uint96 safeAmount = safe96(amount, "XMCB::mint: amount exceeds 96 bits");
        _balances[account] = add96(
            _balances[account],
            safeAmount,
            "XMCB::_increaseBalance: balance overflows"
        );
        _rawTotalSupply = add96(
            _rawTotalSupply,
            safeAmount,
            "XMCB::_deposit: deposit amount overflows"
        );
        _moveDelegates(address(0), getDelegate(account), safeAmount);
    }

    function _burnRaw(address account, uint256 amount) internal virtual {
        uint96 safeAmount = safe96(amount, "XMCB::burn: amount exceeds 96 bits");
        _balances[account] = sub96(
            _balances[account],
            safeAmount,
            "XMCB::_decreaseBalance: balance overflows"
        );
        _rawTotalSupply = sub96(
            _rawTotalSupply,
            safeAmount,
            "XMCB::_deposit: deposit amount overflows"
        );
        _moveDelegates(getDelegate(account), address(0), safeAmount);
    }

    function _balanceFactor() internal view returns (uint256) {
        if (_rawTotalSupply == 0) {
            return WONE;
        }
        return _wdiv(_totalSupply, _rawTotalSupply);
    }

    function _wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y) / WONE;
    }

    function _wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(WONE).add(y / 2).div(y);
    }

    uint256[50] private __gap;
}
