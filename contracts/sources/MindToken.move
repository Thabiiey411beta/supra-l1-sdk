module LiquiMind::MindToken {
    use supra::supra_coin::{Self, SupraCoin};
    use supra::signer;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};

    const TOTAL_SUPPLY: u64 = 10_000_000_000_000_000_000_000; // 10B
    const BURN_RATE: u64 = 50; // 0.5% (50 basis points)

    struct MindToken has key {
        total_supply: u64,
        balances: Table<address, u64>,
        burned: u64,
    }

    struct VestingSchedule has key {
        beneficiary: address,
        amount: u64,
        release_time: u64,
    }

    public entry fun initialize(account: &signer) {
        let token = MindToken {
            total_supply: TOTAL_SUPPLY,
            balances: table::new(),
            burned: 0,
        };
        table::add(&mut token.balances, signer::address_of(account), TOTAL_SUPPLY);
        move_to(account, token);
        event::emit(TokenInitialized { total_supply: TOTAL_SUPPLY });
    }

    public entry fun transfer(sender: &signer, recipient: address, amount: u64) acquires MindToken {
        let token = borrow_global_mut<MindToken>(@LiquiMind);
        let sender_addr = signer::address_of(sender);
        assert!(*table::borrow(&token.balances, sender_addr) >= amount, 100);
        let burn_amount = amount * BURN_RATE / 10000;
        let net_amount = amount - burn_amount;
        *table::borrow_mut(&mut token.balances, sender_addr) = *table::borrow(&token.balances, sender_addr) - amount;
        *table::borrow_mut_with_default(&mut token.balances, recipient, &0) = *table::borrow_with_default(&token.balances, recipient, &0) + net_amount;
        token.burned = token.burned + burn_amount;
        event::emit(TokenTransfer { sender: sender_addr, recipient, amount, burn_amount });
    }

    public entry fun create_vesting(account: &signer, beneficiary: address, amount: u64, release_time: u64) acquires MindToken {
        let token = borrow_global_mut<MindToken>(@LiquiMind);
        let sender_addr = signer::address_of(account);
        table::upsert(&mut token.balances, sender_addr, *table::borrow(&token.balances, sender_addr) - amount);
        move_to(account, VestingSchedule { beneficiary, amount, release_time });
    }

    public entry fun claim_vesting(account: &signer) acquires VestingSchedule, MindToken {
        let vesting = move_from<VestingSchedule>(signer::address_of(account));
        assert!(timestamp::now_seconds() >= vesting.release_time, 100);
        let token = borrow_global_mut<MindToken>(@LiquiMind);
        table::upsert(&mut token.balances, vesting.beneficiary, *table::borrow_with_default(&token.balances, vesting.beneficiary, &0) + vesting.amount);
    }

    public fun balance_of(account: address): u64 acquires MindToken {
        *table::borrow_with_default(&borrow_global<MindToken>(@LiquiMind).balances, account, &0)
    }
}