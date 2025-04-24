module LiquiMind::Staking {
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use LiquiMind::MindToken;
    use LiquiMind::RewardNFT;

    const BASE_APR: u64 = 5; // 5% base APR
    const MAX_APR: u64 = 20; // 20% max with NFT boost

    struct Stake has copy, drop {
        user: address,
        amount: u64,
        start_time: u64,
        nft_boost: u64,
    }

    struct StakingPool has key {
        stakes: Table<address, Stake>,
        total_staked: u64,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, StakingPool {
            stakes: table::new(),
            total_staked: 0,
        });
    }

    public entry fun stake(account: &signer, amount: u64, nft_id: u64) acquires StakingPool, RewardNFT {
        let user = signer::address_of(account);
        let pool = borrow_global_mut<StakingPool>(@LiquiMind);
        let nft_manager = borrow_global<RewardNFT::NFTManager>(@LiquiMind);
        let nft_boost = if (table::contains(&nft_manager.nfts, nft_id)) {
            let nft = table::borrow(&nft_manager.nfts, nft_id);
            assert!(nft.owner == user, 100);
            nft.staking_boost
        } else { 0 };
        MindToken::transfer(account, @LiquiMind, amount);
        let stake = Stake {
            user,
            amount,
            start_time: timestamp::now_seconds(),
            nft_boost,
        };
        table::upsert(&mut pool.stakes, user, stake);
        pool.total_staked = pool.total_staked + amount;
        event::emit(StakeEvent { user, amount, nft_boost });
    }

    public entry fun unstake(account: &signer) acquires StakingPool {
        let user = signer::address_of(account);
        let pool = borrow_global_mut<StakingPool>(@LiquiMind);
        let stake = table::remove(&mut pool.stakes, user);
        let reward = calculate_reward(stake.amount, stake.start_time, stake.nft_boost);
        pool.total_staked = pool.total_staked - stake.amount;
        MindToken::transfer(@LiquiMind, user, stake.amount + reward);
        event::emit(UnstakeEvent { user, amount: stake.amount, reward });
    }

    fun calculate_reward(amount: u64, start_time: u64, nft_boost: u64): u64 {
        let duration = timestamp::now_seconds() - start_time;
        let apr = BASE_APR + nft_boost;
        if (apr > MAX_APR) { apr = MAX_APR };
        (amount * apr * duration) / (100 * 31_536_000) // Annualized
    }
}