module LiquiMind::Bridge {
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use LiquiMind::MindToken;

    struct BridgeRequest has copy, drop {
        user: address,
        chain_id: u64,
        amount: u64,
        destination: address,
        timestamp: u64,
    }

    struct BridgeManager has key {
        requests: Table<u64, BridgeRequest>,
        request_count: u64,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, BridgeManager {
            requests: table::new(),
            request_count: 0,
        });
    }

    public entry fun request_bridge(account: &signer, chain_id: u64, amount: u64, destination: address) acquires BridgeManager {
        let user = signer::address_of(account);
        let manager = borrow_global_mut<BridgeManager>(@LiquiMind);
        MindToken::transfer(account, @LiquiMind, amount);
        let request = BridgeRequest {
            user,
            chain_id,
            amount,
            destination,
            timestamp: timestamp::now_seconds(),
        };
        table::add(&mut manager.requests, manager.request_count, request);
        manager.request_count = manager.request_count + 1;
        event::emit(BridgeRequestEvent { id: manager.request_count - 1, user, chain_id, amount, destination });
    }

    public entry fun execute_bridge(account: &signer, request_id: u64) acquires BridgeManager {
        let manager = borrow_global_mut<BridgeManager>(@LiquiMind);
        let request = table::remove(&mut manager.requests, request_id);
        event::emit(BridgeExecutedEvent { id: request_id, user: request.user, chain_id: request.chain_id, amount: request.amount });
    }
}