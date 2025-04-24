import streamlit as st
import requests
import json
from supra_l1_sdk import SupraClient
from cryptography.fernet import Fernet
import os
from dotenv import load_dotenv
import asyncio
import pandas as pd
import plotly.express as px
from urllib.parse import parse_qs

load_dotenv()
SUPRA_RPC = os.getenv("SUPRA_RPC")
ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY")
CHAINGPT_API_KEY = os.getenv("CHAINGPT_API_KEY")
cipher = Fernet(ENCRYPTION_KEY)

st.set_page_config(page_title="LiquiMind", layout="wide", initial_sidebar_state="expanded")

async def get_supra_client():
    return await SupraClient.init(SUPRA_RPC)

def load_css():
    with open("style.css") as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

def main():
    load_css()
    query_params = st.experimental_get_query_params()
    if "wallet" in query_params:
        st.session_state.wallet = query_params["wallet"][0]

    st.sidebar.title("LiquiMind")
    page = st.sidebar.radio("Navigate", ["Dashboard", "Subscriptions", "Notifications", "NFT Marketplace", "Analytics", "Trading", "Portfolio", "Learn & Earn", "Governance", "Referral", "Social Trading", "Liquidity Pools"])

    if "wallet" not in st.session_state:
        st.session_state.wallet = ""

    wallet = st.sidebar.text_input("Wallet Address", value=st.session_state.wallet, help="Enter your Supra wallet address")
    if wallet:
        st.session_state.wallet = wallet

    if page == "Dashboard":
        st.header("Dashboard")
        if st.session_state.wallet:
            with st.spinner("Fetching data..."):
                response = requests.get(f"http://localhost:5000/api/signals/{st.session_state.wallet}")
                signals = response.json() if response.status_code == 200 else []
                response = requests.get(f"http://localhost:5000/api/portfolio/{st.session_state.wallet}")
                portfolio = response.json() if response.status_code == 200 else {}
            st.subheader("Trading Signals")
            for s in signals:
                col1, col2 = st.columns([3, 1])
                col1.write(f"{s['pair']}: {s['action']} (Confidence: {s['confidence']}%)")
                if col2.button("Trade Now", key=f"trade_{s['id']}", help="Execute trade for this signal"):
                    requests.post("http://localhost:5000/api/one_click_trade", json={
                        "wallet": st.session_state.wallet, "pair": s["pair"], "action": s["action"]
                    })
                    st.success("Trade executed!")
            st.subheader("Portfolio")
            st.write(f"Total Value: ${portfolio.get('total_usd', 0):.2f}")
            if st.button("Rebalance Portfolio", help="Rebalance your portfolio"):
                requests.post("http://localhost:5000/api/rebalance_portfolio", json={"wallet": st.session_state.wallet})
                st.success("Portfolio rebalanced!")
        else:
            st.error("Please connect wallet.")

    elif page == "Subscriptions":
        st.header("Subscriptions")
        tiers = [
            {"name": "Free", "mind": 0, "perks": ["Basic whale alerts", "Paper trading"]},
            {"name": "Basic", "mind": 500_000_000_000_000_000, "perks": ["Full whale tracking", "Grid trading"]},
            {"name": "Pro", "mind": 1_000_000_000_000_000_000, "perks": ["Self-learning AI", "Auto trading", "Governance"]},
            {"name": "Elite", "mind": 2_500_000_000_000_000_000, "perks": ["Priority alerts", "Mythic NFTs", "Insurance"]},
        ]
        tier = st.selectbox("Select Tier", [t["name"] for t in tiers], help="Choose your subscription tier")
        is_yearly = st.checkbox("Yearly (10% discount)", help="Save 10% with annual billing")
        selected_tier = next(t for t in tiers if t["name"] == tier)
        cost = selected_tier["mind"] * (0.9 if is_yearly else 1)
        st.write(f"Cost: {cost / 1_000_000_000_000_000_000:.2f} $MIND")
        if st.button("Subscribe", help="Subscribe to selected tier"):
            if st.session_state.wallet:
                requests.post("http://localhost:5000/api/subscribe", json={
                    "wallet": st.session_state.wallet, "tier": tiers.index(selected_tier), "isYearly": is_yearly
                })
                st.success("Subscription updated!")
            else:
                st.error("Please connect wallet.")

    elif page == "Notifications":
        st.header("Notifications")
        if st.session_state.wallet:
            response = requests.get(f"http://localhost:5000/api/notifications/{st.session_state.wallet}")
            notifications = response.json() if response.status_code == 200 else []
            for n in notifications:
                metadata = json.loads(cipher.decrypt(n["metadata"]).decode()) if n["metadata"] else {}
                st.write(f"{n['timestamp']}: {n['message']} (Activity: {n['activity']}, Perks: {metadata.get('perks', 'None')})")
                if n["activity"] != "subscription_renewal":
                    if st.button(f"Mint NFT ({n['activity']})", key=f"mint_{n['id']}", help="Mint NFT for this activity"):
                        requests.post("http://localhost:5000/api/mint_nft", json={
                            "wallet": st.session_state.wallet, "activity": n["activity"]
                        })
                        st.success("NFT minted!")
                else:
                    if st.button("Renew Subscription", key=f"renew_{n['id']}", help="Renew your subscription"):
                        st.session_state.page = "Subscriptions"
                        st.experimental_rerun()
        else:
            st.error("Please connect wallet.")

    elif page == "NFT Marketplace":
        st.header("NFT Marketplace")
        response = requests.get("http://localhost:5000/api/nfts")
        nfts = response.json() if response.status_code == 200 else []
        for nft in nfts:
            col1, col2 = st.columns([3, 1])
            col1.write(f"{nft['name']} (Rarity: {['Common', 'Rare', 'Legendary', 'Mythic'][nft['rarity']]}, Voting Power: {nft['voting_power']}, Staking Boost: {nft['staking_boost']}%, Fee Discount: {nft['fee_discount']}%)")
            if col2.button("Trade", key=f"trade_nft_{nft['id']}", help="Trade this NFT"):
                st.success(f"Trading {nft['name']} initiated!")

    elif page == "Analytics":
        st.header("Analytics")
        response = requests.get("http://localhost:5000/api/analytics/subscriptions")
        subscriptions = response.json() if response.status_code == 200 else []
        st.subheader("Subscription Trends")
        df_subs = pd.DataFrame(subscriptions)[["wallet_address", "new_tier", "timestamp"]]
        fig_subs = px.line(df_subs.groupby("timestamp").count().reset_index(), x="timestamp", y="wallet_address", title="Subscription Upgrades Over Time")
        st.plotly_chart(fig_subs)
        response = requests.get("http://localhost:5000/api/analytics/nfts")
        nfts = response.json() if response.status_code == 200 else []
        st.subheader("NFT Minting")
        df_nfts = pd.DataFrame(nfts)[["wallet_address", "nft_id", "rarity", "timestamp"]]
        fig_nfts = px.histogram(df_nfts, x="rarity", title="NFT Rarity Distribution")
        st.plotly_chart(fig_nfts)
        response = requests.get("http://localhost:5000/api/analytics/trading")
        trading = response.json() if response.status_code == 200 else []
        st.subheader("Trading Volume")
        df_trading = pd.DataFrame(trading)[["pair", "volume_usd", "timestamp"]]
        fig_trading = px.line(df_trading.groupby("timestamp").sum().reset_index(), x="timestamp", y="volume_usd", title="Trading Volume Over Time")
        st.plotly_chart(fig_trading)

    elif page == "Trading":
        st.header("Auto Trading")
        if st.session_state.wallet:
            pair = st.selectbox("Trading Pair", ["MIND/USD", "ETH/USD", "BNB/USD"], help="Select trading pair")
            amount = st.number_input("Amount ($MIND)", min_value=0.0, step=0.1, help="Amount to trade")
            stop_loss = st.number_input("Stop Loss (USD)", min_value=0.0, step=0.1, help="Set stop loss")
            take_profit = st.number_input("Take Profit (USD)", min_value=0.0, step=0.1, help="Set take profit")
            if st.button("Set Trade", help="Configure auto trading"):
                requests.post("http://localhost:5000/api/set_trade_config", json={
                    "wallet": st.session_state.wallet, "pair": pair, "amount": int(amount * 1e18),
                    "stop_loss": int(stop_loss * 1e18), "take_profit": int(take_profit * 1e18), "enabled": True
                })
                st.success("Trade config set!")
        else:
            st.error("Please connect wallet.")

    elif page == "Portfolio":
        st.header("Portfolio Management")
        if st.session_state.wallet:
            response = requests.get(f"http://localhost:5000/api/portfolio/{st.session_state.wallet}")
            portfolio = response.json() if response.status_code == 200 else {}
            st.write(f"Total Value: ${portfolio.get('total_usd', 0):.2f}")
            st.subheader("Set Target Allocation")
            allocations = st.text_area("Target Allocation (JSON)", '{"MIND": 0.5, "ETH": 0.3, "BNB": 0.2}', help="Enter JSON allocation")
            if st.button("Update Allocation", help="Update portfolio allocation"):
                requests.post("http://localhost:5000/api/set_portfolio_config", json={
                    "wallet": st.session_state.wallet, "target_allocation": allocations
                })
                st.success("Allocation updated!")
        else:
            st.error("Please connect wallet.")

    elif page == "Learn & Earn":
        st.header("Learn & Earn")
        if st.session_state.wallet:
            headers = {"Authorization": f"Bearer {CHAINGPT_API_KEY}"}
            response = requests.get("https://api.chaingpt.org/courses", headers=headers)
            courses = response.json().get("courses", []) if response.status_code == 200 else []
            for c in courses:
                st.subheader(c["title"])
                st.write(c.get("description", "Learn about blockchain and DeFi."))
                if st.button(f"Complete {c['title']}", key=f"course_{c['id']}", help="Complete this course"):
                    requests.post("http://localhost:5000/api/complete_course", json={
                        "wallet": st.session_state.wallet, "course_id": c["id"]
                    })
                    st.success(f"Completed {c['title']}! Earned {c['reward_mind'] / 1_000_000_000_000_000_000:.2f} $MIND.")
        else:
            st.error("Please connect wallet.")

    elif page == "Governance":
        st.header("Governance")
        if st.session_state.wallet:
            response = requests.get("http://localhost:5000/api/proposals")
            proposals = response.json() if response.status_code == 200 else []
            st.subheader("Proposals")
            for p in proposals:
                col1, col2, col3 = st.columns([3, 1, 1])
                col1.write(f"Proposal {p['id']}: {p['description']} (Ends: {p['end_time']})")
                if col2.button("Vote Yes", key=f"vote_yes_{p['id']}", help="Vote yes on proposal"):
                    requests.post("http://localhost:5000/api/vote", json={
                        "wallet": st.session_state.wallet, "proposal_id": p["id"], "vote_yes": True
                    })
                    st.success("Voted Yes!")
                if col3.button("Vote No", key=f"vote_no_{p['id']}", help="Vote no on proposal"):
                    requests.post("http://localhost:5000/api/vote", json={
                        "wallet": st.session_state.wallet, "proposal_id": p["id"], "vote_yes": False
                    })
                    st.success("Voted No!")
            description = st.text_area("New Proposal Description", help="Propose a change")
            if st.button("Create Proposal", help="Create new proposal"):
                requests.post("http://localhost:5000/api/create_proposal", json={
                    "wallet": st.session_state.wallet, "description": description
                })
                st.success("Proposal created!")
        else:
            st.error("Please connect wallet.")

    elif page == "Referral":
        st.header("Referral Program")
        if st.session_state.wallet:
            st.subheader("Your Referral Link")
            referral_link = f"https://liqui-mind.streamlit.app?referrer={st.session_state.wallet}"
            st.write(referral_link)
            if st.button("Copy Link", help="Copy referral link"):
                st.write("Link copied to clipboard!")
            st.subheader("Your Referrals")
            response = requests.get(f"http://localhost:5000/api/referrals/{st.session_state.wallet}")
            referrals = response.json() if response.status_code == 200 else []
            df_referrals = pd.DataFrame(referrals)[["referee", "reward_mind", "timestamp"]]
            st.write(df_referrals)
            total_rewards = sum(r["reward_mind"] for r in referrals) / 1_000_000_000_000_000_000
            st.write(f"Total Rewards: {total_rewards:.2f} $MIND")
        else:
            st.error("Please connect wallet.")

    elif page == "Social Trading":
        st.header("Social Trading")
        if st.session_state.wallet:
            response = requests.get("http://localhost:5000/api/top_traders")
            traders = response.json() if response.status_code == 200 else []
            st.subheader("Top Traders")
            for t in traders:
                col1, col2 = st.columns([3, 1])
                col1.write(f"{t['wallet']}: {t['strategy']} (Performance: {t['roi']}% ROI)")
                if col2.button("Copy Strategy", key=f"copy_{t['wallet']}", help="Copy trader's strategy"):
                    requests.post("http://localhost:5000/api/copy_strategy", json={
                        "wallet": st.session_state.wallet, "trader": t["wallet"]
                    })
                    st.success(f"Copied {t['strategy']}!")
        else:
            st.error("Please connect wallet.")

    elif page == "Liquidity Pools":
        st.header("Liquidity Pools")
        if st.session_state.wallet:
            st.subheader("Available Pools")
            pools = [
                {"pair": "MIND/USD", "apr": 12, "tvl": 1000000},
                {"pair": "MIND/ETH", "apr": 15, "tvl": 500000}
            ]
            for p in pools:
                col1, col2 = st.columns([3, 1])
                col1.write(f"{p['pair']} (APR: {p['apr']}%, TVL: ${p['tvl']})")
                if col2.button("Add Liquidity", key=f"pool_{p['pair']}", help="Add liquidity to pool"):
                    st.success(f"Adding liquidity to {p['pair']} initiated!")
        else:
            st.error("Please connect wallet.")

if __name__ == "__main__":
    main()