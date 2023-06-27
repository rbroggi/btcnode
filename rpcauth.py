#!/usr/bin/env python3
# Copyright (c) 2015-2021 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

from argparse import ArgumentParser
from getpass import getpass
from secrets import token_hex, token_urlsafe
import hmac

def generate_salt(size):
    """Create size byte hex salt"""
    return token_hex(size)

def generate_password():
    """Create 32 byte b64 password"""
    return token_urlsafe(32)

def password_to_hmac(salt, password):
    m = hmac.new(salt.encode('utf-8'), password.encode('utf-8'), 'SHA256')
    return m.hexdigest()

def main():
    parser = ArgumentParser(description='Create login credentials for a JSON-RPC user')
    parser.add_argument('username', help='the username for authentication')
    parser.add_argument('password', help='leave empty to generate a random password or specify "-" to prompt for password', nargs='?')
    args = parser.parse_args()

    pwd_confirm = ''
    if not args.password:
        args.password = generate_password()
    elif args.password == '-':
        args.password = getpass()
        pwd_confirm = getpass()
        if pwd_confirm != args.password:
            print('password and password-confirm do not match')
            raise ValueError("Password and password-confirm do not match")

    # Create 16 byte hex salt
    salt = generate_salt(16)
    password_hmac = password_to_hmac(salt, args.password)

    auth_string = f'rpcauth={args.username}:{salt}${password_hmac}'

    replace_line('bitcoin/bitcoin.conf', 'rpcauth=', auth_string)


    print('String to be appended to bitcoin.conf:')


def replace_line(file_path, search_text, replacement):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    with open(file_path, 'w') as file:
        for line in lines:
            if search_text in line and not line.startswith('#'):
                line = replacement + '\n'
            file.write(line)


if __name__ == '__main__':
    main()
