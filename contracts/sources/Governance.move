module LiquiMind::Governance {
    use supra::supra_account;
    use supra::timestamp;
    use supra::event;
    use supra::table::{Self, Table};
    use supra::signer;
    use LiquiMind::MindToken;
    use LiquiMind::RewardNFT;

    struct Proposal has copy, drop {
        id: u64,
        proposer: address,
        description: vector<u8>,
        start_time: u64,
        end_time: u64,
        yes_votes: u64,
        no_votes: u64,
        executed: bool,
    }

    struct Governance has key {
        proposals: Table<u64, Proposal>,
        proposal_count: u64,
        votes: Table<address, Table<u64, bool>>,
    }

    public entry fun initialize(account: &signer) {
        move_to(account, Governance {
            proposals: table::new(),
            proposal_count: 0,
            votes: table::new(),
        });
    }

    public entry fun create_proposal(account: &signer, description: vector<u8>) acquires Governance {
        let user = signer::address_of(account);
        let gov = borrow_global_mut<Governance>(@LiquiMind);
        let proposal = Proposal {
            id: gov.proposal_count,
            proposer: user,
            description,
            start_time: timestamp::now_seconds(),
            end_time: timestamp::now_seconds() + 604_800, // 1 week
            yes_votes: 0,
            no_votes: 0,
            executed: false,
        };
        table::add(&mut gov.proposals, gov.proposal_count, proposal);
        gov.proposal_count = gov.proposal_count + 1;
        event::emit(ProposalCreated { id: proposal.id, proposer: user, description });
    }

    public entry fun vote(account: &signer, proposal_id: u64, vote_yes: bool) acquires Governance, RewardNFT {
        let user = signer::address_of(account);
        let gov = borrow_global_mut<Governance>(@LiquiMind);
        let proposal = table::borrow_mut(&mut gov.proposals, proposal_id);
        assert!(timestamp::now_seconds() < proposal.end_time, 100);
        let voting_power = MindToken::balance_of(user);
        let nft_manager = borrow_global<RewardNFT::NFTManager>(@LiquiMind);
        let i = 0;
        while (i < nft_manager.nft_count) {
            let nft = table::borrow(&nft_manager.nfts, i);
            if (nft.owner == user) {
                voting_power = voting_power + nft.voting_power;
            };
            i = i + 1;
        };
        if (!table::contains(&gov.votes, user)) {
            table::add(&mut gov.votes, user, table::new());
        };
        let user_votes = table::borrow_mut(&mut gov.votes, user);
        table::upsert(user_votes, proposal_id, vote_yes);
        if (vote_yes) {
            proposal.yes_votes = proposal.yes_votes + voting_power;
        } else {
            proposal.no_votes = proposal.no_votes + voting_power;
        };
        event::emit(VoteCast { user, proposal_id, vote_yes, voting_power });
    }

    public entry fun execute_proposal(account: &signer, proposal_id: u64) acquires Governance {
        let gov = borrow_global_mut<Governance>(@LiquiMind);
        let proposal = table::borrow_mut(&mut gov.proposals, proposal_id);
        assert!(timestamp::now_seconds() >= proposal.end_time, 100);
        assert!(!proposal.executed, 101);
        if (proposal.yes_votes > proposal.no_votes) {
            proposal.executed = true;
            event::emit(ProposalExecuted { id: proposal_id });
        };
    }
}