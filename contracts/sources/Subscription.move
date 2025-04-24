module LiquiMind::Subscription {
    use supra::supra_coin::SupraCoin;
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use supra::price_feed::{Self, PriceFeed};
    use LiquiMind::MindToken;

    const TIER_FREE: u8 = 0;
    const TIER_BASIC: u8 = 1;
    const TIER_PRO: u8 = 2;
    const TIER_ELITE: u8 = 3;
    const BASIC_COST_MIND: u64 = 500_000_000_000_000_000; // ~$5
    const PRO_COST_MIND: u64 = 1_000_000_000_000_000_000; // ~$10
    const ELITE_COST_MIND: u64 = 2_500_000_000_000_000_000; // ~$25
    const YEARLY_DISCOUNT: u64 = 10;

    struct Subscription has copy, drop {
        user: address,
        tier: u8,
        expiry: u64,
        mind_cost: u64,
    }

    struct SubscriptionManager has key {
        subscriptions: Table<address, Subscription>,
        revenue_mind: u64,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, SubscriptionManager {
            subscriptions: table::new(),
            revenue_mind: 0,
        });
    }

    public entry fun subscribe(account: &signer, tier: u8, is_yearly: bool) acquires SubscriptionManager {
        let user = signer::address_of(account);
        let manager = borrow_global_mut<SubscriptionManager>(@LiquiMind);
        let mind_cost = if (tier == TIER_BASIC) { BASIC_COST_MIND }
                       else if (tier == TIER_PRO) { PRO_COST_MIND }
                       else if (tier == TIER_ELITE) { ELITE_COST_MIND }
                       else { 0 };
        if (is_yearly && mind_cost > 0) {
            mind_cost = mind_cost * 12 * (100 - YEARLY_DISCOUNT) / 100;
        };
        if (mind_cost > 0) {
            MindToken::transfer(account, @LiquiMind, mind_cost);
            manager.revenue_mind = manager.revenue_mind + mind_cost;
        };
        let expiry = if (is_yearly) { timestamp::now_seconds() + 31_536_000 } else { timestamp::now_seconds() + 2_592_000 };
        let subscription = Subscription { user, tier, expiry, mind_cost };
        table::upsert(&mut manager.subscriptions, user, subscription);
        event::emit(subscription);
        if (tier >= TIER_BASIC) {
            let rarity = if (tier == TIER_ELITE) { b"mythic" } else if (tier == TIER_PRO) { b"legendary" } else { b"rare" };
            supra::call_function(@LiquiMind, "RewardNFT", "track_activity", [user, b"subscribe", 1, b"Subscription NFT", rarity, b""]);
        };
    }

    public fun get_subscription(user: address): (u8, u64, u64) acquires SubscriptionManager {
        let manager = borrow_global<SubscriptionManager>(@LiquiMind);
        if (table::contains(&manager.subscriptions, user)) {
            let sub = table::borrow(&manager.subscriptions, user);
            (sub.tier, sub.expiry, sub.mind_cost)
        } else {
            (TIER_FREE, 0, 0)
        }
    }
}