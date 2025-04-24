module LiquiMind::LearnEarn {
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use LiquiMind::MindToken;

    struct Course has copy, drop {
        id: u64,
        title: vector<u8>,
        reward_mind: u64,
        reward_nft_rarity: u8,
    }

    struct LearnEarnManager has key {
        courses: Table<u64, Course>,
        completions: Table<address, Table<u64, bool>>,
        course_count: u64,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, LearnEarnManager {
            courses: table::new(),
            completions: table::new(),
            course_count: 0,
        });
    }

    public entry fun add_course(account: &signer, title: vector<u8>, reward_mind: u64, reward_nft_rarity: u8) acquires LearnEarnManager {
        let manager = borrow_global_mut<LearnEarnManager>(@LiquiMind);
        let course = Course {
            id: manager.course_count,
            title,
            reward_mind,
            reward_nft_rarity,
        };
        table::add(&mut manager.courses, manager.course_count, course);
        manager.course_count = manager.course_count + 1;
        event::emit(CourseAdded { id: course.id, title, reward_mind, reward_nft_rarity });
    }

    public entry fun complete_course(account: &signer, course_id: u64) acquires LearnEarnManager {
        let user = signer::address_of(account);
        let manager = borrow_global_mut<LearnEarnManager>(@LiquiMind);
        let course = table::borrow(&manager.courses, course_id);
        if (!table::contains(&manager.completions, user)) {
            table::add(&mut manager.completions, user, table::new());
        };
        let user_completions = table::borrow_mut(&mut manager.completions, user);
        assert!(!table::contains(user_completions, course_id), 100);
        table::add(user_completions, course_id, true);
        MindToken::transfer(@LiquiMind, user, course.reward_mind);
        let rarity = if (course.reward_nft_rarity == 3) { b"mythic" } else if (course.reward_nft_rarity == 2) { b"legendary" } else if (course.reward_nft_rarity == 1) { b"rare" } else { b"common" };
        supra::call_function(@LiquiMind, "RewardNFT", "track_activity", [user, b"complete_course", 1, b"Learn & Earn NFT", rarity, b""]);
        event::emit(CourseCompleted { user, course_id, reward_mind: course.reward_mind });
    }
}