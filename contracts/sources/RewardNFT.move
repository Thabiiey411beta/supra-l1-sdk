module LiquiMind::RewardNFT {
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use LiquiMind::Subscription::{Self, get_subscription};

    const RARITY_COMMON: u8 = 0;
    const RARITY_RARE: u8 = 1;
    const RARITY_LEGENDARY: u8 = 2;
    const RARITY_MYTHIC: u8 = 3;

    struct NFT has copy, drop {
        id: u64,
        owner: address,
        rarity: u8,
        metadata: vector<u8>,
        voting_power: u64,
        staking_boost: u64,
        fee_discount: u64,
        timestamp: u64,
    }

    struct PendingNFT has copy, drop {
        activity: vector<u8>,
        rarity: u8,
        metadata: vector<u8>,
    }

    struct ActivityTracker has key {
        user_activities: Table<address, Table<vector<u8>, u64>>,
        pending_nfts: Table<address, vector<PendingNFT>>,
    }

    struct NFTManager has key {
        nfts: Table<u64, NFT>,
        nft_count: u64,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, ActivityTracker {
            user_activities: table::new(),
            pending_nfts: table::new(),
        });
        move_to(account, NFTManager {
            nfts: table::new(),
            nft_count: 0,
        });
    }

    public entry fun track_activity(account: &signer, activity: vector<u8>, increment: u64, metadata: vector<u8>) acquires ActivityTracker {
        let user = signer::address_of(account);
        let tracker = borrow_global_mut<ActivityTracker>(@LiquiMind);
        if (!table::contains(&tracker.user_activities, user)) {
            table::add(&mut tracker.user_activities, user, table::new());
        };
        let activities = table::borrow_mut(&mut tracker.user_activities, user);
        let count = if (table::contains(activities, activity)) {
            *table::borrow(activities, activity)
        } else { 0 };
        table::upsert(activities, activity, count + increment);

        let (tier, _) = Subscription::get_subscription(user);
        let threshold = get_threshold_from_oracle(activity, tier); // Supra oracle
        let rarity = if (tier == 3) { RARITY_MYTHIC } else if (tier == 2) { RARITY_LEGENDARY } else if (tier == 1) { RARITY_RARE } else { RARITY_COMMON };
        let voting_power = if (rarity == RARITY_MYTHIC) { 200 } else if (rarity == RARITY_LEGENDARY) { 100 } else if (rarity == RARITY_RARE) { 40 } else { 10 };
        let staking_boost = if (rarity == RARITY_MYTHIC) { 20 } else if (rarity == RARITY_LEGENDARY) { 15 } else if (rarity == RARITY_RARE) { 10 } else { 5 };
        let fee_discount = if (rarity == RARITY_MYTHIC) { 10 } else if (rarity == RARITY_LEGENDARY) { 5 } else if (rarity == RARITY_RARE) { 3 } else { 0 };
        let pending_nfts = if (!table::contains(&tracker.pending_nfts, user)) {
            vector::empty<PendingNFT>()
        } else {
            *table::borrow(&tracker.pending_nfts, user)
        };
        if (count >= threshold) {
            vector::push_back(&mut pending_nfts, PendingNFT { activity, rarity, metadata });
            table::upsert(&mut tracker.pending_nfts, user, pending_nfts);
            event::emit(PendingNFTEvent { user, activity, rarity, metadata });
        };
    }

    public entry fun mint_nft(account: &signer, activity: vector<u8>) acquires ActivityTracker, NFTManager {
        let user = signer::address_of(account);
        let tracker = borrow_global_mut<ActivityTracker>(@LiquiMind);
        let manager = borrow_global_mut<NFTManager>(@LiquiMind);
        let pending_nfts = table::borrow_mut(&mut tracker.pending_nfts, user);
        let i = 0;
        while (i < vector::length(pending_nfts)) {
            let pending = vector::borrow(pending_nfts, i);
            if (pending.activity == activity) {
                let voting_power = if (pending.rarity == RARITY_MYTHIC) { 200 } else if (pending.rarity == RARITY_LEGENDARY) { 100 } else if (pending.rarity == RARITY_RARE) { 40 } else { 10 };
                let staking_boost = if (pending.rarity == RARITY_MYTHIC) { 20 } else if (pending.rarity == RARITY_LEGENDARY) { 15 } else if (pending.rarity == RARITY_RARE) { 10 } else { 5 };
                let fee_discount = if (pending.rarity == RARITY_MYTHIC) { 10 } else if (pending.rarity == RARITY_LEGENDARY) { 5 } else if (pending.rarity == RARITY_RARE) { 3 } else { 0 };
                let nft = NFT {
                    id: manager.nft_count,
                    owner: user,
                    rarity: pending.rarity,
                    metadata: pending.metadata,
                    voting_power,
                    staking_boost,
                    fee_discount,
                    timestamp: timestamp::now_seconds(),
                };
                table::add(&mut manager.nfts, manager.nft_count, nft);
                manager.nft_count = manager.nft_count + 1;
                vector::remove(pending_nfts, i);
                event::emit(NFTMintedEvent { user, nft_id: nft.id, activity, rarity: nft.rarity, timestamp: nft.timestamp });
                break;
            };
            i = i + 1;
        };
    }
}