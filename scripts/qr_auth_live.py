import asyncio
import getpass
import os
from pathlib import Path

from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError


SESSION_PATH = "/data/session/telegram_backup_qr_live"
QR_URL_PATH = Path("/data/session/qr_login_url.txt")


async def main():
    client = TelegramClient(
        SESSION_PATH,
        int(os.environ["TELEGRAM_API_ID"]),
        os.environ["TELEGRAM_API_HASH"],
    )
    await client.connect()
    try:
        if await client.is_user_authorized():
            print("ALREADY_AUTHORIZED", flush=True)
            return

        print("QR_FLOW_STARTED", flush=True)

        while True:
            try:
                qr = await client.qr_login()
            except SessionPasswordNeededError:
                # A previous QR scan can leave Telegram waiting only for 2FA.
                print("TELEGRAM_2FA_REQUIRED", flush=True)
                password = getpass.getpass("Enter Telegram 2FA password: ")
                await client.sign_in(password=password)
                break

            QR_URL_PATH.write_text(qr.url, encoding="utf-8")
            print("NEW_QR_READY", flush=True)

            try:
                await qr.wait()
                break
            except SessionPasswordNeededError:
                print("TELEGRAM_2FA_REQUIRED", flush=True)
                password = getpass.getpass("Enter Telegram 2FA password: ")
                await client.sign_in(password=password)
                break
            except TimeoutError:
                # Token expired before being confirmed; loop regenerates a new one.
                print("QR_EXPIRED_REGENERATING", flush=True)
                continue

        if await client.is_user_authorized():
            print("QR_AUTHORIZED", flush=True)
        else:
            print("NOT_AUTHORIZED", flush=True)
    finally:
        await client.disconnect()


asyncio.run(main())