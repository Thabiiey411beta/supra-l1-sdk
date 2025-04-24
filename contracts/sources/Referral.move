module LiquiMind::Referral {
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use LiquiMind::MindToken;
    use LiquiMind::RewardNFT;

    struct Referral has copy, drop {
        referrer: address,
        referee: address,
        reward_mind: u64,
        timestamp: u64,
    }

    struct ReferralManager has key {
        referrals: Table<address, vector<Referral>>,
        total_rewards: u64,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, ReferralManager {
            referrals: table::new(),
            total_rewards: 0,
        });
    }

    public entry fun refer(account: &signer, referee: address) acquires ReferralManager {
        let referrer = signer::address_of(account);
        let manager = borrow_global_mut<ReferralManager>(@LiquiMind);
        if (!table::contains(&manager.referrals, referrer)) {
            table::add(&mut manager.referrals, referrer, vector::empty<Referral>());
        };
        let referrals = table::borrow_mut(&mut manager.referrals, referrer);
        let reward_mind = 100_000_000_000_000_000; // 100 $MIND
        let referral = Referral {
            referrer,
            referee,
            reward_mind,
            timestamp: timestamp::now_seconds(),
        };
        vector::push_back(referrals, referral);
        manager.total_rewards = manager.total_rewards + reward_mind;
        MindToken::transfer(@LiquiMind, referrer, reward_mind);
        supra::call_function(@LiquiMind, "RewardNFT", "track_activity", [referrer, b"referral", 1, b"Referral NFT", b"rare", b""]);
        event::emit(ReferralEvent { referrer, referee, reward_mind });
    }

    public fun get_referrals(user: address): vector<Referral> acquires ReferralManager {
        let manager = borrow_global<ReferralManager>(@LiquiMind);
        if (table::contains(&manager.referrals, user)) {
            *table::borrow(&manager.referrals, user)
        } else {
            vector::empty<Referral>()
        }
    }
}