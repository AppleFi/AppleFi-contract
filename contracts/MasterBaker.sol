pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BakeryToken.sol";


interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to BakeryToken.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.

    function migrate(IERC20 token) external returns (IERC20);
}

// MasterBaker is the master of ApplePie.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once APLFI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterBaker is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of APPLEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accApplePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accApplePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. APPLEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that APPLEs distribution occurs.
        uint256 accApplePerShare; // Accumulated APPLEs per share, times 1e12. See below.
    }

    // The Bakery TOKEN!
    BakeryToken public bToken;

    address public lottery;
    address public treasury;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when the mining starts.
    uint256 public startBlock;
    uint256 public TARGET_SUPPLY = 5000000 ether;
    uint256 public INIT_SUPPLY =3000000 ether;
    uint256 public BLOCKS_PER_PHASE = 16;
    uint256 public BLOCKS_PER_WEEK = 4;
    uint256 START_REWARD_PERCENT = 5;
    uint256 START_PHASE_REWARD_PERCENT_COEFF= 20*2;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        BakeryToken _token,
        address _lottery,
        address _treasury
    ) public {
        bToken = _token;
        lottery = _lottery;
        treasury = _treasury;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setBakeryToken(address _token) public onlyOwner {
        bToken = BakeryToken(_token);
    }

    function startBaking(uint256 waitBlock) public onlyOwner {
        if (bToken.totalSupply() == 0 ) {
            bToken.mint( address(this), INIT_SUPPLY);
        }
        startBlock = block.number.add(waitBlock);
    }

    function resetStartBlock(uint256 u) public onlyOwner {
        startBlock = u;
    }

    function getUserInfo(uint256 _pid, address _user) public view returns ( uint256, uint256) {
        UserInfo memory user =userInfo[_pid][_user];
        return (user.amount, user.rewardDebt) ;
    }

    function getPoolInfo(uint256 _pid) public view returns (IERC20 , uint256, uint256,uint256, uint256 ) {
        PoolInfo memory pi =poolInfo[_pid];
        uint256 lpSupply = pi.lpToken.balanceOf(address(this));
        return (pi.lpToken, pi.accApplePerShare.div(1e12),pi.allocPoint,pi.lastRewardBlock,lpSupply ) ;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accApplePerShare: 0
        }));
    }

    // Update the given pool's APPLE allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // View function to see pending reward on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accApplePerShare = pool.accApplePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 reward = getReward(pool.lastRewardBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accApplePerShare = accApplePerShare.add(reward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accApplePerShare).div(1e12).sub(user.rewardDebt);
    }

    function getReward(uint256 lastRewardBlock ) public view returns (uint256){
        if (block.number <= lastRewardBlock) {
            return 0;
        }
        return getAccRewardAt(block.number).sub(getAccRewardAt(lastRewardBlock));
    }

    function getAccRewardAt(uint256 at_block) public view returns (uint256) {
        uint256 elapsedBlock =at_block.sub(startBlock);
        if (elapsedBlock == 0) return 0;
        uint256 phase_1 = elapsedBlock.div(BLOCKS_PER_PHASE); //.add(1);  //phase-1
        uint256 week_reward = START_REWARD_PERCENT.mul(1e12).div(2**phase_1);  // week_reward*1e12

        //0.2*((1-0.5^(phase-1))/0.5) = 40*(1-0.5^(phase-1)) =40* (1-1/2^(phase-1))
        uint256 acc_phase_reward_percent = START_PHASE_REWARD_PERCENT_COEFF.mul(uint256(1e12).sub(uint256(1e12).div(2**phase_1)));
        uint256 blocks_in_phase=elapsedBlock.sub(phase_1.mul(BLOCKS_PER_PHASE));
        uint256 reward_in_phase = blocks_in_phase.mul(week_reward).div(BLOCKS_PER_WEEK);
        uint256 acc_reward_percent = acc_phase_reward_percent.add(reward_in_phase);
        uint256 acc_reward = acc_reward_percent.mul(TARGET_SUPPLY).div(1e14);  //    acc_reward_percent/100 /1e12
        return acc_reward;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 reward = getReward(pool.lastRewardBlock);
        uint256 fees = reward.div(100);
        bToken.mint(treasury, fees);
        bToken.mint(lottery, fees);
        bToken.mint(address(this), reward);
        pool.accApplePerShare = pool.accApplePerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterBaker for Bakery token allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accApplePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeAppleTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accApplePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Master
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accApplePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeAppleTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accApplePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe apple transfer function, just in case if rounding error causes pool to not have enough APPLEs.
    function safeAppleTransfer(address _to, uint256 _amount) internal {
        uint256 appleBal = bToken.balanceOf(address(this));
        if (_amount > appleBal) {
            bToken.transfer(_to, appleBal);
        } else {
            bToken.transfer(_to, _amount);
        }
    }

    // Update lottery address by the previous lottery.
    function modifyLottery(address _lottery) public {
        require(msg.sender == lottery, "mismatch lottery");
        lottery = _lottery;
    }
    
    function modifyTreasury(address _treasury) public {
        require(msg.sender == treasury, "mismatch treasury");
        treasury = _treasury;
    }

    function freeze(address target, bool f) public onlyOwner {
        bToken.freeze(target, f);
    }

    //EMERGENCY ONLY
    function transferTokenOwnership(address newOwner) public onlyOwner {
        bToken.transferOwnership(newOwner);
    }
}