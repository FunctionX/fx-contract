// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract ERC20Interface {

    function transfer(address to, uint tokens) public virtual returns (bool success);

    function transferFrom(address from, address to, uint tokens) public virtual returns (bool success);

}

contract PurseTokenUpgradable is Initializable, UUPSUpgradeable, PausableUpgradeable, OwnableUpgradeable {

    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;
    uint256 public minimumSupply;
    address[] public admins;
    address public liqPool;
    address public disPool;
    uint256 public burnPercent;
    uint256 public liqPercent;
    uint256 public disPercent;

    uint256 public _averageInterval;
    uint256 public _getRewardEndTime;
    uint256 public _getRewardStartTime;
    uint256 public _numOfDaysPerMth;
    uint256 public _monthlyDistributePr;
    uint256 public _percentageDistribute;
    uint256 public _lastRewardStartTime;
    uint256 public _totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isWhitelistedTo;
    mapping(address => bool) public isWhitelistedFrom;
    mapping(address => AccAmount) public accAmount;

    struct AccAmount {
        uint256 amount;
        uint256 accReward;
        uint256 lastUpdateTime;
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Burn(address indexed _from, uint256 _value);
    event Mint(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not Admin");
        _;
    }

    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool success)
    {
        require(balanceOf[msg.sender] >= _value, "Not enough balance");
        if (isWhitelistedTo[_to] || isWhitelistedFrom[msg.sender]) {
            updateAccumulateBalanceTransaction(msg.sender, _to);
            balanceOf[msg.sender] -= _value;
            balanceOf[_to] += _value;


            emit Transfer(msg.sender, _to, _value);
            return true;
        } else {
            updateAccumulateBalanceTransaction(msg.sender, _to);
            uint256 transferValue = _partialBurn(_value, msg.sender);
            balanceOf[msg.sender] -= transferValue;
            balanceOf[_to] += transferValue;


            emit Transfer(msg.sender, _to, transferValue);
            return true;
        }
    }

    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool success)
    {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool success) {
        require(_value <= balanceOf[_from], "Not enough balance");
        require(_value <= allowance[_from][msg.sender], "Not enough allowance");
        if (isWhitelistedTo[_to] || isWhitelistedFrom[msg.sender]) {
            allowance[_from][msg.sender] -= _value;
            updateAccumulateBalanceTransaction(_from, _to);
            balanceOf[_from] -= _value;
            balanceOf[_to] += _value;

            emit Transfer(_from, _to, _value);
            return true;
        } else {
            allowance[_from][msg.sender] -= _value;
            updateAccumulateBalanceTransaction(_from, _to);
            uint256 transferValue = _partialBurn(_value, _from);
            balanceOf[_from] -= transferValue;
            balanceOf[_to] += transferValue;

            emit Transfer(_from, _to, transferValue);
            return true;
        }
    }

    function mint(address _account, uint256 _amount) public whenNotPaused onlyAdmin {
        require(_account != address(0), "0 address");
        updateAccumulateBalance(_account);
        balanceOf[_account] += _amount;

        totalSupply += _amount;
        emit Mint(address(0), _account, _amount);
    }

    function burn(uint256 _amount) public whenNotPaused {
        require(_amount != 0, "0 address");
        require(balanceOf[msg.sender] >= _amount, "Not enough balance");
        updateAccumulateBalance(msg.sender);
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        emit Burn(msg.sender, _amount);
    }

    function updateAccumulateBalance(address _holder) private {
        if (accAmount[_holder].lastUpdateTime == 0) {
            if (_getRewardStartTime == 0) {
                uint256 interval = (block.timestamp - _lastRewardStartTime)/ _averageInterval;
                accAmount[_holder].lastUpdateTime = _lastRewardStartTime + (interval * _averageInterval);   //1 day = 86400 seconds
            } else {
                if (block.timestamp < _getRewardStartTime) {
                    uint256 interval = (block.timestamp - _lastRewardStartTime)/ _averageInterval;
                    accAmount[_holder].lastUpdateTime = _lastRewardStartTime + (interval * _averageInterval);   //1 day = _timeDecimal seconds
                } else {
                    uint256 interval = (block.timestamp - _getRewardStartTime)/ _averageInterval;
                    accAmount[_holder].lastUpdateTime = _getRewardStartTime + (interval * _averageInterval);
                }
            }
        }
        else if (block.timestamp < _getRewardStartTime) {
            if (accAmount[_holder].lastUpdateTime < _lastRewardStartTime) {
                uint256 interval = (block.timestamp - _lastRewardStartTime)/ _averageInterval;
                uint256 accumulateAmount = balanceOf[_holder] * interval;
                accAmount[_holder].lastUpdateTime = _lastRewardStartTime + (interval * _averageInterval);   //1 day = 86400 seconds
                accAmount[_holder].amount = accumulateAmount;
            }
            else {
                uint256 interval = (block.timestamp - accAmount[_holder].lastUpdateTime)/ _averageInterval;
                if (interval >= 1) {
                    uint256 accumulateAmount = balanceOf[_holder] * interval;
                    accAmount[_holder].lastUpdateTime += (interval * _averageInterval);
                    accAmount[_holder].amount = accAmount[_holder].amount + accumulateAmount;
                }
            }
        }
        else if(block.timestamp >= _getRewardStartTime) {
            if (accAmount[_holder].lastUpdateTime < _lastRewardStartTime) {
                uint256 interval = (_getRewardStartTime - _lastRewardStartTime)/ _averageInterval;
                uint256 lastmonthAccAmount = balanceOf[_holder] * interval;
                accAmount[_holder].amount = 0;
                accAmount[_holder].accReward = lastmonthAccAmount * _monthlyDistributePr * _percentageDistribute * 100 / _totalSupply / _numOfDaysPerMth / 10000;
                accAmount[_holder].lastUpdateTime = _getRewardStartTime;
                updateAccumulateBalance(_holder);
            }
            else if (accAmount[_holder].lastUpdateTime >= _lastRewardStartTime && accAmount[_holder].lastUpdateTime < _getRewardStartTime) {
                uint256 interval = (_getRewardStartTime - accAmount[_holder].lastUpdateTime)/ _averageInterval;
                if (interval >= 1) {
                    uint256 accumulateAmount = balanceOf[_holder] * interval;
                    uint256 lastmonthAccAmount = accAmount[_holder].amount + accumulateAmount;
                    accAmount[_holder].amount = 0;
                    accAmount[_holder].accReward = lastmonthAccAmount * _monthlyDistributePr * _percentageDistribute * 100 / _totalSupply / _numOfDaysPerMth / 10000;
                    accAmount[_holder].lastUpdateTime = _getRewardStartTime;
                    updateAccumulateBalance(_holder);
                }
                else {
                    uint256 lastmonthAccAmount = accAmount[_holder].amount;
                    accAmount[_holder].amount = 0;
                    accAmount[_holder].accReward = lastmonthAccAmount * _monthlyDistributePr * _percentageDistribute * 100 / _totalSupply / _numOfDaysPerMth / 10000;
                    accAmount[_holder].lastUpdateTime = _getRewardStartTime;
                    updateAccumulateBalance(_holder);
                }
            }
            else {
                uint256 interval = (block.timestamp - accAmount[_holder].lastUpdateTime)/ _averageInterval;
                if (interval >= 1) {
                    uint256 accumulateAmount = balanceOf[_holder] * interval;
                    accAmount[_holder].lastUpdateTime += (interval * _averageInterval);
                    accAmount[_holder].amount = accAmount[_holder].amount + accumulateAmount;
                }
            }
        }
    }



    function updateAccumulateBalanceTransaction(address _from, address _to) private {
        updateAccumulateBalance(_from);
        updateAccumulateBalance(_to);
    }

    function claimDistributionPurse() public whenNotPaused returns(bool success) {
        require(block.timestamp > _getRewardStartTime, "Claim not started");
        require(block.timestamp < _getRewardEndTime, "Claim period over");

        updateAccumulateBalance(msg.sender);
        require(accAmount[msg.sender].accReward > 0, "User reward is 0");
        uint256 claimAmount = accAmount[msg.sender].accReward;
        accAmount[msg.sender].accReward = 0;

        ERC20Interface(address(this)).transfer(msg.sender, claimAmount);
        return true;
    }

    function activateClaimMonthly(uint256 _rewardStartTime, uint256 _rewardEndTime, uint256 _monthlyDisPr, uint256 _numOfDays, uint256 _percentage) public onlyAdmin {
        require(_rewardStartTime > block.timestamp, "Less than current time");
        require(_rewardEndTime > _rewardStartTime, "Less than start time");
        require(_numOfDays > 0, "Less than 0");
        require(_percentage > 0 && _percentage <= 100, "Less than 0 or More than 100");
        require(_monthlyDisPr <= balanceOf[address(this)], "More than pool balance");

        _totalSupply = totalSupply;
        if (_getRewardStartTime != 0) {
            _lastRewardStartTime = _getRewardStartTime;
        }
        // _lastRewardStartTime = _getRewardStartTime;
        _numOfDaysPerMth = _numOfDays;
        _getRewardStartTime = _rewardStartTime;
        _getRewardEndTime = _rewardEndTime;
        _percentageDistribute = _percentage;
        _monthlyDistributePr = _monthlyDisPr;
    }

    function _partialBurn(uint256 _amount, address _from) internal returns (uint256) {
        uint256 transferAmount = 0;
        uint256 burnAmount;
        uint256 liqAmount;
        uint256 disAmount;
        (
            burnAmount,
            liqAmount,
            disAmount
        ) = _calculateDeductAmount(_amount);

        if (burnAmount >= 0 || liqAmount >= 0 || disAmount >= 0) {
            burnPrivate(_from, burnAmount, liqAmount, disAmount);
        }
        transferAmount = _amount - burnAmount - liqAmount - disAmount;

        return transferAmount;
    }

    function _calculateDeductAmount(uint256 _amount) internal view returns (uint256, uint256, uint256) {
        uint256 burnAmount;
        uint256 liqAmount;
        uint256 disAmount;

        if (totalSupply > minimumSupply) {
            burnAmount = (_amount * burnPercent) / 100;
            liqAmount = (_amount * liqPercent) / 100;
            disAmount = (_amount * disPercent) / 100;
            uint256 availableBurn = totalSupply - minimumSupply;
            if (burnAmount > availableBurn) {
                burnAmount = availableBurn;
            }
        }
        return (burnAmount, liqAmount, disAmount);
    }

    function burnPrivate( address _account, uint256 _burnAmount, uint256 _liqAmount, uint256 _disAmount) private {
        require(_account != address(0), "0 address");
        uint256 accountBalance = balanceOf[_account];
        uint256 deductAmount = _burnAmount + _liqAmount + _disAmount;
        require(accountBalance >= deductAmount, "Not enough balance");
        balanceOf[_account] -= _burnAmount;
        balanceOf[_account] -= _liqAmount;
        balanceOf[_account] -= _disAmount;

        totalSupply -= _burnAmount;
        // updateAccumulateBalanceTransaction(disPool, liqPool);
        balanceOf[liqPool] += _liqAmount;
        balanceOf[disPool] += _disAmount;

        emit Burn(_account, _burnAmount);
        emit Transfer(msg.sender, liqPool, _liqAmount);
        emit Transfer(msg.sender, disPool, _disAmount);
    }

    function updateLPoolAdd(address _newLPool) public onlyOwner {
        require(_newLPool != liqPool, "Same with previous address");

        liqPool = _newLPool;
    }

    function updateDPoolAdd(address _newDPool) public onlyOwner {
        require(_newDPool != disPool, "Same with previous address");

        disPool = _newDPool;
    }

    function updatePercent(uint256 _newDisPercent, uint256 _newLiqPercent, uint256 _newBurnPercent) public onlyOwner {
        require(_newDisPercent >= 0 && _newDisPercent <= 100 && _newLiqPercent >= 0 && _newLiqPercent <= 100 && _newBurnPercent >= 0 && _newBurnPercent <= 100, "% < 0 or > 100");
        require(_newDisPercent + _newLiqPercent + _newBurnPercent <= 100, "Total more than 100");

        disPercent = _newDisPercent;
        liqPercent = _newLiqPercent;
        burnPercent = _newBurnPercent;
    }

    function updateMinimumSupply(uint256 _minimumSupply) public onlyOwner {
        minimumSupply = _minimumSupply;
    }

    function addAdmin(address newAdmin) public onlyOwner{
        require(!isAdmin[newAdmin], "Is admin");

        isAdmin[newAdmin] = true;
        admins.push(newAdmin);
    }

    function removeAdmin(uint index) public onlyOwner returns (address[] memory){
        address removeOwner = admins[index];
        require(index < admins.length, "Input over admins length");
        require(isAdmin[removeOwner], "Not an admin");

        for (uint i = index; i<admins.length-1; i++){
            admins[i] = admins[i+1];
        }
        admins.pop();

        isAdmin[removeOwner] = false;
        return admins;
    }

    function transferERCToken(address token, uint256 amount, address _to) public whenNotPaused onlyOwner{
        require(_to != address(0), "0 address");
        if (token == address(this)) {
            updateAccumulateBalance(_to);
            ERC20Interface(token).transfer(_to, amount);
        } else {
            ERC20Interface(token).transfer(_to, amount);
        }
    }

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    function setWhitelistedTo(address newWhitelist) public onlyOwner {
        require(!isWhitelistedTo[newWhitelist], "Whilisted Address");

        isWhitelistedTo[newWhitelist] = true;
    }

    function removeWhitelistedTo(address newWhitelist) public onlyOwner {
        require(isWhitelistedTo[newWhitelist], "Non whilisted Address");

        isWhitelistedTo[newWhitelist] = false;
    }

    function setWhitelistedFrom(address newWhitelist) public onlyOwner {
        require(!isWhitelistedFrom[newWhitelist], "Whilisted Address");

        isWhitelistedFrom[newWhitelist] = true;
    }

    function removeWhitelistedFrom(address newWhitelist) public onlyOwner {
        require(isWhitelistedFrom[newWhitelist], "Non whilisted Address");

        isWhitelistedFrom[newWhitelist] = false;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _to,
        address _lPool,
        uint256 _burnPercent,
        uint256 _liqPercent,
        uint256 _disPercent
    ) public initializer {
        require(_lPool != address(0), "0 address");
        require(_burnPercent >= 0, "Percentage is 0");
        require(_liqPercent >= 0, "Percentage is 0");
        require(_disPercent >= 0, "Percentage is 0");

        name = "PURSE TOKEN";
        symbol = "PURSE";
        totalSupply = 64000000000 * (10**18); // 64 billion tokens
        decimals = 18;
        minimumSupply = 12800000000 * (10 ** 18);

        liqPool = _lPool;
        disPool = address(this);
        burnPercent = _burnPercent;
        liqPercent = _liqPercent;
        disPercent = _disPercent;
        _averageInterval = 1 days;
        _lastRewardStartTime = block.timestamp;
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        balanceOf[_to] = totalSupply;
        updateAccumulateBalance(_to);
        emit Mint(address(0), _to, totalSupply);
    }
}