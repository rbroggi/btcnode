#!/usr/bin/env python3
# Copyright (c) 2015-2021 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
from argparse import ArgumentParser
from getpass import getpass
from secrets import token_hex, token_urlsafe
from sys import stderr
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
    parser.add_argument('file', help='the env file where the variable RPCAUTH will be appended')
    args = parser.parse_args()

    args.password = getpass()
    pwd_confirm = ''
    pwd_confirm = getpass()
    if pwd_confirm != args.password:
        print('password and password-confirm do not match', file=stderr)
        raise ValueError("Password and password-confirm do not match")

    # Create 16 byte hex salt
    salt = generate_salt(16)
    password_hmac = password_to_hmac(salt, args.password)

    append(args.file, f'RPCAUTH=\'{args.username}:{salt}${password_hmac}\'\n')


def append(destination_file_path, append_str):
    with open(destination_file_path, 'a') as file:
        file.write(append_str)

if __name__ == '__main__':
    main()
