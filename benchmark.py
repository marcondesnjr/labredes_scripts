#!/usr/bin/env python3

import os, subprocess, time, shlex

SERVER_IP = '192.168.111.158'
SERVER_USER = 'root'
PRIVATE_KEY_PATH = os.path.join('~','.ssh','labredes')
CONTAINER_ID = 'c581c8956aa6'
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
SERVICES_LIST = ['apache2', 'nginx','quic']
TCP_ALGOS_LIST = ['cubic', 'bic', 'westwood', 'hybla']
TESTS_LIST = [
    {'req': 500, 'conc':50},
    {'req': 200, 'conc':10}
]
DATA_DIR = os.path.join(SCRIPT_DIR, 'data')
TEST_URL = 'http://192.168.122.13/'
MAX_RETRY = 0
RETRY_DELAY = 2

UPLOAD_DATA = False
COMPRESS_DATA = True


def main():
    print('Preparing directories')
    make_dirs()

    print('Stopping all servers')
    shutdown_all_services()

    #for algo in TCP_ALGOS_LIST: #<- Change order
    for service in SERVICES_LIST:
        #print(f'Configuring algorithm {algo}')
        print(f'Starting service {service}')
        if service == 'quic':
            run_in_docker(f'service nginx start')
        else:
            run_in_docker(f'service {service} start')
        #change_tcp_alg(algo)
        #for service in SERVICES_LIST: #<- Change order
        for algo in TCP_ALGOS_LIST:
            #print(f'Starting service {service}')
            print(f'Configuring algorithm {algo}')
            change_tcp_alg(algo)
            #run_in_docker(f'service {service} start')
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                for i in range(MAX_RETRY+1):
                    try:
                        print(f'Running {req} requests with {conc} concurrency')
                        test_name = f'{service}_cubic_{algo}_{req}r{conc}c'
                        test_folder = os.path.join(DATA_DIR, service, algo, f'{req}r{conc}c')
                        test_output = os.path.join(test_folder, f'{test_name}_out.txt')
                        test_csv = os.path.join(test_folder,f'{test_name}.csv')
                        if service == 'quic':
                            cmd = f'ab -n {req} -c {conc} -e "{test_csv}" {TEST_URL[:-1]}:8443/'
                        else:
                            cmd = f'ab -n {req} -c {conc} -e "{test_csv}" {TEST_URL}'
                        with open(test_output, 'w') as output_file:
                            run_local(cmd, output_file)
                        break
                    except Exception as e:
                        print(e)
                        print('Test Failed')
                        print('Retrying')
                        time.sleep(RETRY_DELAY)
            #print(f'Stopping service {service}')
            #run_in_docker(f'service {service} stop')
        print(f'Stopping service {service}')
        if service == 'quic':
            run_in_docker(f'service nginx stop')
        else:
            run_in_docker(f'service {service} stop')

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
    
def change_tcp_alg(algo):
    run_in_server(f'sysctl net.ipv4.tcp_congestion_control={algo}')

def shutdown_all_services():
    cmd = ''
    for service in SERVICES_LIST:
        if service == 'quic':
            cmd += f'service nginx stop; '
        else:
            cmd += f'service {service} stop; '
    run_in_docker(cmd)

#Send a command to docker container running in the server
def run_in_docker(cmd):
    run_in_server(f'docker exec {CONTAINER_ID} bash -c \\"{cmd}\\"')


#Send a command to the server
def run_in_server(cmd):
    full_cmd = f'ssh {SERVER_USER}@{SERVER_IP} -i {PRIVATE_KEY_PATH} "{cmd}"'
    #print(shlex.split(full_cmd))
    p=subprocess.run(shlex.split(full_cmd), check=True)
    return p.stdout

def run_local(cmd, out=None):
    #print(shlex.split(cmd))
    p=subprocess.run(shlex.split(cmd), check=True, stdout=out)
    return p.stdout
    

#Make data dirs
def make_dirs():
    for service in SERVICES_LIST:
        for algo in TCP_ALGOS_LIST:
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                os.makedirs(os.path.join(DATA_DIR,service,algo,f'{req}r{conc}c'), exist_ok=True)

main()
