#!/usr/bin/env python3

import os
import subprocess
import time
import shlex

SERVER = 'www.netlab.com'
SERVER_PATH = '/sample-3s.mp3'
SERVER_USER = 'root'
SERVER_IP = '192.168.0.15'
PRIVATE_KEY_PATH = os.path.join('/', 'home','djr' ,'tmp.8rYlEhsQMo', 'tempid')
CONTAINER_ID = '29df'
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
TCP_ALGOS_LIST = ['cubic', 'bic', 'westwood', 'htcp', 'hybla', 'vegas', 'nv', 'scalable', 'lp', 'veno', 'yeah', 'illinois', 'dctcp', 'cdg', 'bbr']
TESTS_LIST = [
    {'req': 2000, 'conc': 100},
    {'req': 10000, 'conc': 500},
    {'req': 20000, 'conc': 1000},
    ]
DATA_DIR = os.path.join(SCRIPT_DIR, 'data')
#TEST_URL = 'http://192.168.122.13/'
MAX_RETRY = 1
RETRY_DELAY = 10

UPLOAD_DATA = True
COMPRESS_DATA = True

def main():
    nginx = TestService('nginx', 'service nginx start', 'service nginx stop', "https://{}{}".format(SERVER, SERVER_PATH))
    apache2 = TestService('apache2', 'service apache2 start', 'service apache2 stop', "https://{}{}".format(SERVER, SERVER_PATH))
    quic = TestService('quic', 'service nginx start', 'service nginx stop', "https://{}:8443{}".format(SERVER, SERVER_PATH))

    SERVICES_LIST = [nginx, apache2, quic]

    print('Preparing directories')
    make_dirs(SERVICES_LIST)

    print('Stopping all servers')
    shutdown_all_services(SERVICES_LIST)

    for service in SERVICES_LIST:
        print('Starting service {}'.format(service.name))
        run_in_docker(service.up_command)

        for algo in TCP_ALGOS_LIST:
            print('Configuring algorithm {}'.format(algo))
            change_tcp_alg(algo)
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                for i in range(MAX_RETRY + 1):
                    try:
                        print('Running {} requests with {} concurrency'.format(req, conc))
                        test_name = service.get_test_name(req, conc, algo)
                        test_folder = os.path.join(DATA_DIR, service.name, algo, '{}r{}c'.format(req, conc))
                        test_output = os.path.join(test_folder, '{}_out.txt'.format(test_name))
                        cmd = service.get_test_command(req, conc, algo)
                        with open(test_output, 'w') as output_file:
                            run_local(cmd, output_file)
                        break
                    except Exception as e:
                        print(e)
                        print('Test Failed')
                        print('Retrying')
                        time.sleep(RETRY_DELAY)
        print('Stopping service {}'.format(service.name))
        run_in_docker(service.down_command)

    if COMPRESS_DATA:
        print('Compressing results')
        compressed_data = os.path.join(SCRIPT_DIR, 'data.tar.gz')
        run_local("tar -czvf \"{}\" \"{}\"".format(compressed_data, DATA_DIR))
        print('Done')

    if COMPRESS_DATA and UPLOAD_DATA:
        try:
            print('Trying to upload the file')
            run_local("curl bashupload.com -T \"{}\"".format(compressed_data))
        except:
            print('Upload failed =(')

class TestService: 
    def __init__(self, name, up_command, down_command, test_url):
        self.name = name
        self.up_command = up_command
        self.down_command = down_command
        self.test_url = test_url

    def get_test_command(self, req, conc, algo):
        test_name = self.get_test_name(req, conc, algo)
        test_folder = os.path.join(DATA_DIR, self.name, algo, '{}r{}c'.format(req, conc))
        test_csv = os.path.join(test_folder, '{}.csv'.format(test_name))
        return "ab -n {} -c {} -e \"{}\" {}".format(req, conc, test_csv, self.test_url)

    def get_test_name(self, req, conc, algo):
        return "{}_cubic_{}_{}r{}c".format(self.name, algo, req, conc)
    
def change_tcp_alg(algo):
    run_in_server("sysctl net.ipv4.tcp_congestion_control={}".format(algo))

def shutdown_all_services(services_list):
    cmd = ''
    for service in services_list:
        cmd += "{}; ".format(service.down_command)
        run_in_docker(cmd)

def run_in_docker(cmd):
    docker_cmd = "docker exec {} bash -c \\\"{}\\\"".format(CONTAINER_ID, cmd)
    run_in_server(docker_cmd)

def run_in_server(cmd):
    full_cmd = "ssh {}@{} -i {} \"{}\"".format(SERVER_USER, SERVER_IP,PRIVATE_KEY_PATH, cmd)
    p = subprocess.Popen(shlex.split(full_cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    if p.returncode != 0:
        raise subprocess.CalledProcessError(p.returncode, full_cmd, output=stdout)
    print(stdout)
    return stdout

def run_local(cmd, out=None):
    if out is None:
        p = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
            raise subprocess.CalledProcessError(p.returncode, cmd, output=stdout)
        print(stdout)
        return stdout
    else: p = subprocess.Popen(shlex.split(cmd), stdout=out, stderr=subprocess.PIPE)
    _, stderr = p.communicate()
    if p.returncode != 0:
        raise subprocess.CalledProcessError(p.returncode, cmd, output="")

def make_dirs(services_list):
    for service in services_list:
        for algo in TCP_ALGOS_LIST:
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                os.makedirs(os.path.join(DATA_DIR, service.name, algo, '{}r{}c'.format(req, conc)), exist_ok=True)

if __name__ == '__main__':
    main()