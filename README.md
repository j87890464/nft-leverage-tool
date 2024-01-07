# AppWorks School final project: NFT 槓桿工具聚合器

**專案概述：整合 BendDAO、Floor Protocol 的 NFT 槓桿工具聚合器**

**1. BendDAO：Peer-to-pool NFT 借貸協議**

BendDAO 是一個 Peer-to-pool NFT 借貸協議，用戶可以使用其擁有的 NFT 作為抵押品，借取 ETH。該平台提供更靈活的 NFT 資產管理和借貸選項，同時確保用戶在槓桿操作中有更大的彈性。

**2. Floor Protocol：NFT 碎片化協議**

Floor Protocol 將單個 NFT 碎片化為 100 萬顆 ERC20 代幣，以提高流動性。這種標準化的碎片化 NFT 體驗可以使 NFT 更容易進入市場，同時確保相同 NFT 項目的碎片是相同的。

**3. NFT Floor Price Feeds：NFT 地板價格查詢**

Chainlink 提供查詢 NFT 地板價格的工具，使用戶能夠更精確地預測 NFT 的價值變動。

**功能：**

1. **槓桿:**
   - 最多可以創造 NFT 地板價格 60% 的槓桿（即最高約 1.6 倍槓桿）。
   - 流程是透過 BendDAO 進行 NFT 抵押借款，再去 Uniswap 將借款轉換為 Floor Protocol 產生的該 NFT 碎片化代幣，以達到對標該 NFT 槓桿。

2. **去槓桿:**
   - 流程為 Uniswap 將 Floor Protocol 產生的該 NFT 碎片化代幣轉換為 ETH 進行還款。
   - 用戶可以設置最大還款數目，當還款數目可以償還 BendDAO 借款加上利息後，即可去槓桿並將 NFT 贖回。

3. **風險管理:**
   - 透過 Chainlink 提供的 NFT floor price feeds 和 Uniswap 計算大約市場價值。
   - Helth factor 查詢
   - 提供給用戶判斷是否進行去槓桿或賣出套利的參考。

**總結：**

整合 BendDAO 和 Floor Protocol，提供了一個 NFT 槓桿工具，使 NFT 擁有者能夠更靈活地管理其資產、參與市場並探索更多金融機會。

## Usage

### Build

```shell
$ forge build
```

### Setting
Set MAINNET_RPC_URL, PRIVATE_KEY environment variables in .env file.

### Test

Test NFTLeverageV1 on main net fork
```shell
$ forge test
or
$ forge test --mc NFTLeverageTest
```
