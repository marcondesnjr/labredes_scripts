#!/usr/bin/env python3

import os, subprocess, time, shlex

SERVER_PATH = '192.168.111.158'
SERVER_USER = 'root'
PRIVATE_KEY_PATH = os.path.join('~','.ssh','labredes')
CONTAINER_ID = 'c581c8956aa6'
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
TCP_ALGOS_LIST = ['cubic', 'bic', 'westwood', 'hybla']
TESTS_LIST = [
    {'req': 500, 'conc':50},
    {'req': 200, 'conc':10},
    {'req': 1000, 'conc':100},
]
DATA_DIR = os.path.join(SCRIPT_DIR, 'data')
TEST_URL = 'http://192.168.122.13/'
MAX_RETRY = 0
RETRY_DELAY = 2

UPLOAD_DATA = False
COMPRESS_DATA = True


def main():

    nginx = TestService('nginx', 'service nginx start', 'service nginx stop', f'http://{SERVER_PATH}/')
    apache2 = TestService('apache2', 'service apache2 start', 'service apache2 stop', f'http://{SERVER_PATH}/')
    quic = TestService('quic', 'service nginx start', 'service nginx stop', f'http://{SERVER_PATH}:8443/')

    SERVICES_LIST = [nginx, apache2, quic]

    print('Preparing directories')
    make_dirs(SERVICES_LIST)

    print('Stopping all servers')
    shutdown_all_services(SERVICES_LIST)

    for service in SERVICES_LIST:
        print(f'Starting service {service.name}')
        run_in_docker(service.up_command)

        for algo in TCP_ALGOS_LIST:
            print(f'Configuring algorithm {algo}')
            change_tcp_alg(algo)
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                for i in range(MAX_RETRY+1):
                    try:
                        print(f'Running {req} requests with {conc} concurrency')
                        test_name = service.get_test_name(req,conc,algo)
                        test_folder = os.path.join(DATA_DIR, service.name, algo, f'{req}r{conc}c')
                        test_output = os.path.join(test_folder, f'{test_name}_out.txt')
                        cmd = service.get_test_command(req, conc,algo)
                        with open(test_output, 'w') as output_file:
                            run_local(cmd, output_file)
                        break
                    except Exception as e:
                        print(e)
                        print('Test Failed')
                        print('Retrying')
                        time.sleep(RETRY_DELAY)
        print(f'Stopping service {service.name}')
        run_in_docker(service.down_command)

    if COMPRESS_DATA:
        print('Compressing results')
        compressed_data = os.path.join(SCRIPT_DIR, 'data.tar.gz')
        run_local(f'tar -czvf "{compressed_data}" "{DATA_DIR}"')
        print('Done')
    
    if COMPRESS_DATA and UPLOAD_DATA:
        try:
            print('Trying to upload the file')
            run_local(f'curl bashupload.com -T "{compressed_data}"')
        except:
            print('Upload failed =(')

class TestService:
    def __init__(self, name:str, up_command:str, down_command:str, test_url:str):
        self.name = name
        self.up_command = up_command
        self.down_command = down_command
        self.test_url = test_url
    

    def get_test_command(self, req:int, conc:int, algo:str) -> str:
        test_name = self.get_test_name(req, conc, algo)
        test_folder = os.path.join(DATA_DIR, self.name, algo, f'{req}r{conc}c')
        test_csv = os.path.join(test_folder,f'{test_name}.csv')
        return f'ab -n {req} -c {conc} -e "{test_csv}" {self.test_url}'
    
    def get_test_name(self, req:int, conc:int, algo:str) -> str:
        return f'{self.name}_cubic_{algo}_{req}r{conc}c'


def change_tcp_alg(algo):
    run_in_server(f'sysctl net.ipv4.tcp_congestion_control={algo}')

def shutdown_all_services(services_list: list[TestService]):
    cmd = ''
    for service in services_list:
        cmd += f'{service.down_command}; '
    run_in_docker(cmd)

#Send a command to docker container running in the server
def run_in_docker(cmd):
    run_in_server(f'docker exec {CONTAINER_ID} bash -c \\"{cmd}\\"')


#Send a command to the server
def run_in_server(cmd):
    full_cmd = f'ssh {SERVER_USER}@{SERVER_PATH} -i {PRIVATE_KEY_PATH} "{cmd}"'
    #print(shlex.split(full_cmd))
    p=subprocess.run(shlex.split(full_cmd), check=True)
    return p.stdout

def run_local(cmd, out=None):
    #print(shlex.split(cmd))
    p=subprocess.run(shlex.split(cmd), check=True, stdout=out)
    return p.stdout
    

#Make data dirs
def make_dirs(services_list: list[TestService]):
    for service in services_list:
        for algo in TCP_ALGOS_LIST:
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                os.makedirs(os.path.join(DATA_DIR, service.name, algo, f'{req}r{conc}c'), exist_ok=True)

main()
