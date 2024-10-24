import hashlib
import base64


def human_readable_hash(input: str) -> str:
    """
    Returns a fixed length string of length 52 based off the input.
    :param input: A string to hash
    :return: Return a string of length 52
    """
    return base64.b32encode(hashlib.sha256(input.encode("utf-8")).digest()).decode(
        "utf-8"
    )[:-4]
