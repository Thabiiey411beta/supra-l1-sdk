import os
import asyncio
import requests
import pandas as pd
import numpy as np
from supra_l1_sdk import SupraClient, SupraAccount
from cryptography.fernet import Fernet
from stable_baselines3 import PPO
from sklearn.linear_model import SGDClassifier
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from ipfshttpclient import client as IPFSClient
from dotenv import load_dotenv
import logging
import json
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
load_dotenv()

SUPRA_RPC = os.getenv("SUPRA_RPC")
ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY")
CHAINGPT_API_KEY = os.getenv("CHAINGPT_API_KEY")
IPFS_NODE = "/ip4/127.0.0.1/tcp/5001"

def encrypt_data(data: str) -> bytes:
    fernet = Fernet(ENCRYPTION_KEY)
    return fernet.encrypt(data.encode())

class NFTGenerator:
    def __init__(self):
        self.model = AutoModelForCausalLM.from_pretrained("distilgpt2")
        self.tokenizer = AutoTokenizer.from_pretrained("distilgpt2")
        self.ipfs = IPFSClient(IPFS_NODE)

    def generate_metadata(self, activity: str, tier: int, user_id: str) -> dict:
        prompt = f"Create unique NFT metadata for {activity} for user {user_id} in tier {tier}"
        inputs = self.tokenizer(prompt, return_tensors="pt")
        outputs = self.model.generate(inputs["input_ids"], max_length=100, num_return_tensors=1)
        metadata = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        rarity = 0 if tier == 0 else 1 if tier == 1 else 2 if tier == 2 else 3
        voting_power = {0: 10, 1: 40, 2: 100, 3: 200}[rarity]
        staking_boost = {0: 5, 1: 10, 2: 15, 3: 20}[rarity]
        fee_discount = {0: 0, 1: 3, 2: 5, 3: 10}[rarity]
        perks = {
            "complete_course": f"voting_power_{voting_power}",
            "trading_volume": f"fee_discount_{fee_discount}%",
            "subscribe": f"staking_boost_{staking_boost}%",
            "referral": "referral_badge"
        }.get(activity, "custom_badge")
        metadata_dict = {
            "name": f"{activity.replace('_', ' ').title()} NFT",
            "description": metadata,
            "rarity": rarity,
            "perks": perks,
            "voting_power": voting_power,
            "staking_boost": staking_boost,
            "fee_discount": fee_discount
        }
        cid = self.ipfs.add(json.dumps(metadata_dict))["Hash"]
        return {**metadata_dict, "ipfs_cid": cid}

nft_generator = NFTGenerator()

async def fetch_chain_gpt_courses() -> list:
    cache_file = "courses_cache.json"
    if os.path.exists(cache_file):
        with open(cache_file, "r") as f:
            cached = json.load(f)
        if datetime.now().timestamp() - cached["timestamp"] < 3600:  # 1 hour cache
            return cached["courses"]
    headers = {"Authorization": f"Bearer {CHAINGPT_API_KEY}"}
    response = requests.get("https://api.chaingpt.org/courses", headers=headers)
    courses = response.json().get("courses", []) if response.status_code == 200 else []
    with open(cache_file, "w") as f:
        json.dump({"timestamp": datetime.now().timestamp(), "courses": courses}, f)
    return courses

async def log_activity(wallet_address: str, activity: str, count: int):
    supra_client = await SupraClient.init(SUPRA_RPC)
    sender_account = SupraAccount.from_mnemonic(os.getenv("PRIVATE_KEY"))
    metadata = nft_generator.generate_metadata(activity, 1, wallet_address)
    await supra_client.call_function(
        "LiquiMind::RewardNFT",
        "track_activity",
        [wallet_address, activity, count, encrypt_data(json.dumps(metadata))],
        {"signer": sender_account}
    )

class AITuner:
    def __init__(self):
        self.ppo_model = PPO.load("trading_model") if os.path.exists("trading_model.zip") else PPO("MlpPolicy", create_trading_env())

    async def collect_trading_data(self):
        supra_client = await SupraClient.init(SUPRA_RPC)
        trades = await supra_client.query_events("TradeExecutedEvent", limit=1000)
        return pd.DataFrame([(t["pair"], t["amount"], t["timestamp"]) for t in trades], columns=["pair", "amount", "timestamp"])

    async def fine_tune_ppo(self):
        data = await self.collect_trading_data()
        env = create_trading_env(data)
        self.ppo_model.learn(total_timesteps=10000, env=env)
        self.ppo_model.save("trading_model")
        logging.info("PPO model fine-tuned")

    async def fine_tune_loop(self):
        while True:
            await self.fine_tune_ppo()
            await asyncio.sleep(2592000)  # Monthly

async def trading_loop():
    supra_client = await SupraClient.init(SUPRA_RPC)
    sender_account = SupraAccount.from_mnemonic(os.getenv("PRIVATE_KEY"))
    while True:
        wallet_address = sender_account.address().to_string()
        tier, expiry, mind_cost = await supra_client.call_function(
            "LiquiMind::Subscription",
            "get_subscription",
            [wallet_address]
        )
        if expiry < datetime.now().timestamp() and tier > 0:
            continue
        activities = {"trading_volume": 5_000_000_000_000_000_000, "complete_course": 1, "referral": 1}
        for activity, count in activities.items():
            await log_activity(wallet_address, activity, count)
        await asyncio.sleep(60)

async def main():
    await asyncio.gather(
        trading_loop(),
        AITuner().fine_tune_loop()
    )

if __name__ == "__main__":
    asyncio.run(main())