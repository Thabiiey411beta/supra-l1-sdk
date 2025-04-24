import ipfshttpclient

class IPFSClient:
    def __init__(self, node: str):
        self.client = ipfshttpclient.connect(node)

    def add(self, content: str) -> dict:
        return self.client.add_str(content)

    def get(self, cid: str) -> str:
        return self.client.cat(cid).decode()