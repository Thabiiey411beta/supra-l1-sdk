module LiquiMind::AutoTrade {
    use supra::supra_coin::SupraCoin;
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::signer;
    use supra::price_feed::{Self, PriceFeed};
    use LiquiMind::Subscription::{Self, get_subscription};
    use LiquiMind::MindToken;

    struct TradeConfig has copy, drop {
        user: address,
        pair: vector<u8>,
        amount: u64,
        stop_loss: u64,
        take_profit: u64,
        enabled: bool,
    }

    struct TradeManager has key {
        configs: Table<address, vector<TradeConfig>>,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, TradeManager {
            configs: table::new(),
        });
    }

    public entry fun set_trade_config(account: &signer, pair: vector<u8>, amount: u64, stop_loss: u64, take_profit: u64) acquires TradeManager {
        let user = signer::address_of(account);
        let (tier, _) = Subscription::get_subscription(user);
        assert!(tier >= 2, 100);
        let manager = borrow_global_mut<TradeManager>(@LiquiMind);
        if (!table::contains(&manager.configs, user)) {
            table::add(&mut manager.configs, user, vector::empty<TradeConfig>());
        };
        let configs = table::borrow_mut(&mut manager.configs, user);
        vector::push_back(configs, TradeConfig {
            user,
            pair,
            amount,
            stop_loss,
            take_profit,
            enabled: true,
        });
        event::emit(TradeConfigEvent { user, pair, amount, stop_loss, take_profit });
    }

    public entry fun execute_trade(account: &signer, user: address, pair: vector<u8>, signal: u8) acquires TradeManager {
        let manager = borrow_global_mut<TradeManager>(@LiquiMind);
        let configs = table::borrow_mut(&manager.configs, user);
        let i = 0;
        while (i < vector::length(configs)) {
            let config = vector::borrow(configs, i);
            if (config.pair == pair && config.enabled) {
                let price_data = price_feed::get_price(get_pair_id(pair));
                let current_price = price_data.price;
                if (signal == 1 && current_price <= config.take_profit) {
                    MindToken::transfer(account, @LiquiMind, config.amount);
                    event::emit(TradeExecutedEvent { user, pair, amount: config.amount, price: current_price, buy: true });
                } else if (signal == 2 && current_price >= config.stop_loss) {
                    MindToken::transfer(@LiquiMind, user, config.amount);
                    event::emit(TradeExecutedEvent { user, pair, amount: config.amount, price: current_price, buy: false });
                };
            };
            i = i + 1;
        };
    }

    public entry fun toggle_auto_trading(account: &signer, enabled: bool) acquires TradeManager {
        let user = signer::address_of(account);
        let manager = borrow_global_mut<TradeManager>(@LiquiMind);
        let configs = table::borrow_mut(&mut manager.configs, user);
        let i = 0;
        while (i < vector::length(configs)) {
            let config = vector::borrow_mut(configs, i);
            config.enabled = enabled;
            i = i + 1;
        };
    }
}