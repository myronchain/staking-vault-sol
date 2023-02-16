# Staking Vault Solidity

Staking合约

## 需求

> 当产生提前赎回行为：则按以下逻辑说明处理 注⚠️以下说明用字母N代替 
>
> N代表 = 第一笔金额及质押的时间
>
> N+1代表 = 第二笔金额及质押的时间
>
> N+2代表 = 第三笔金额及质押的时间 以此类推！！！ 

1. 质押链和币种
   - BSC：BNB、Busd
   - TRON：tRX、usdt
2. 质押时间：30天
3. 30天利率：60% （暂时写为静态）
4. 质押逻辑：需记录每次的质押金额及质押时间 yyyy-MM-dd-HH-mm
   - 【提前赎回的行为】=【总质押金额】—【赎回金额】
   - 【赎回金额扣除】= 优先扣除最早一笔的（即N）；若赎回金额大于N，则从N+1扣除，以此类推）（注：如果赎回金额>总投入金额，则赎回失败！）
   - 【剩余金额的计算逻辑】=N\*质押时间\*利率 + N+1\*质押时间\*利率......（以此类推）
     - eg：A用户2.9日14点质押某币种100刀；在2.10日12点质押相同币种200刀；累计共300刀，那么如果A用户在2月14日提取了80刀（则按业务逻辑是只返回本金，没有利润），则剩下220刀，这220刀将分开按“质押时间和利率进行计算”（即为：2.9日剩下的20刀计算+2.10日剩下的200刀计算=最后到期时间的利润及本金） 

5. 考虑裂变的问题：所以我们有【邀请业务】A用户邀请B用户，奖励机制：【A用户收取B用户所有质押总额2.5%】10.1 质押XXX时间（待定）后合约收取5%管理费（24h后给邀请者打2.5%邀奖励），若时间不足收取管理费，没有2.5%的邀请奖励

## 合约说明

StakingVault：质押合约

## 合约接口(事件)

### StakingVault

- Staked

  - `_from`: 质押时间

  - `amount`: 质押数量

- TODO

## 合约函数

### StakingVault

#### 质押相关

- 质押代币
  - 函数名：stake

  - 参数：_amount

- 设置质押时间
  - 函数名：setStakingTime
  - 参数：_stakingTime

- 设置质押收益率
  - 函数名：setRewardRate
  - 参数：_rewardRate

- 设置质押银行，用于提取收益
  - 函数名：setStakingBank
  - 参数：_stakingBank

- 获取合约的质押总额
  - 函数名：totalStaked
  - 参数：空

- 获取一段时间内的总质押人数(不按天拆分)
  - 函数名：getStakeNum
  - 参数：startTime、endTime

- 获取一段时间内的总质押金额(不按天拆分)
  - 函数名：getStakeAmount
  - 参数：startTime、endTime

- 获取指定人的质押总额
  - 函数名：stakedOf
  - 参数：_account


#### 提取相关

- 提取本金
  - 函数名：withdraw
  - 参数：_amount
- 提取质押收益
  - 函数名：claimStakeReward
  - 参数：_amount
- 提取推荐收益
  - 函数名：claimReferrerReward
  - 参数：_amount
- 提取所有本金+收益
  - 函数名：claimAllReward
  - 参数：_account
- 提取代币给Owner
  - 函数名：withdrawOwner
  - 参数：_amount
- 计算收益相关数值(定时调用)
  - 函数名：calculateReward
  - 参数：无
- 更新管理费用，然后将邀请奖励费用transfer给推荐人(定时调用)
  - 函数名：calculateManageFee
  - 参数：无
- 获取指定人的收益历史总额
  - 函数名：getRewardCount
  - 参数：_account
- 获取指定人的收益余额
  - 函数名：getRewardsBalance
  - 参数：_account
- 获取指定人邀请收益历史总额
  - 函数名：getReferrerRewardCount
  - 参数：_account
- 获取指定人邀请收益余额
  - 函数名：getReferrerRewardsBalance
  - 参数：_account

#### 推荐相关

- 保存邀请人
  - 函数：setReferrer
  - 参数：_referrer
- 查看邀请人
  - 函数：getReferrer
  - 参数：无




## 安装环境
```shell
npm install
```

## 使用脚本部署
### 设置环境变量
设置从.env.example复制到.env，并修改其中变量。或手动设置环境变量也可以。
ETHERSCAN_API_KEY=ABC123ABC123ABC123ABC123ABC123ABC1
PRIVATE_KEY=0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1
把KEY换成自己的，ETHERSCAN_API_KEY可以不设置（如果不需要再polygonscan能看到合约代码的话）

### 运行部署脚本

1. 在BSC测试网部署

```shell
npx hardhat --network bsctest run scripts/deploy.js
```

2. 在BSC主网部署

```shell
npx hardhat --network bsc run scripts/deploy.js
```

3. 在TRON测试网部署

```shell
npx hardhat --network trontest run scripts/deploy.js
```

4. 在TRON主网部署

```shell
npx hardhat --network tron run scripts/deploy.js
```

## 合约地址

1. BSC测试网：TODO
2. BSC主网：
3. TRON测试网：
4. TRON主网：