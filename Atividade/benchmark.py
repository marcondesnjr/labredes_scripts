#!/usr/bin/env python3

"""
    Script to run tests on a server using ab and different TCP congestion algorithms and services

    This script automates the process of running performance tests on a server using different TCP congestion control
    algorithms and services. It utilizes the Apache Benchmark (ab) tool to measure the performance of services
    running inside a Docker container on the target server. The script performs the following steps:

    1. Defines server and test configurations, including the server address, user credentials,
    Docker container ID, and a list of TCP congestion algorithms and test parameters.
    2. Initializes services to be tested (nginx, apache2, and quic) with their respective start and stop commands and test URLs.
    3. Prepares directories for storing test results.
    4. Stops all running services to ensure a clean testing environment.
    5. Iterates over each service and TCP congestion algorithm, running performance tests with varying numbers
    of requests and concurrency levels.
    6. Saves the test results in a specified directory.
    7. Optionally compresses the test results into a tar.gz file.
    8. Optionally uploads the compressed test results to bashupload.com.

    The script handles retries in case of test failures and provides detailed output for each step of the process.
    
    @author: Marcondes Junior
             github.com/marcondesnjr
"""

import os
import subprocess
import time
import shlex

SERVER = 'www.netlab.com' #Server address to make requests
SERVER_PATH = '/sample-3s.mp3' #Path to the file to be requested
SERVER_USER = 'root' #User to connect to the server via ssh with docker privileges via private key
SERVER_IP = '192.168.0.15' #Server ip address to connect via ssh
PRIVATE_KEY_PATH = os.path.join('/', 'home','djr' ,'tmp.8rYlEhsQMo', 'tempid') #Path to the private key to connect to the server
CONTAINER_ID = '29df' #Docker container id to run commands
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__)) #Directory where the script is located
TCP_ALGOS_LIST = ['cubic', 'bic', 'cdg', 'bbr'] #List of TCP congestion algorithms to be used
TESTS_LIST = [
    {'req': 2000, 'conc': 100},
    ] #List of tests to be performed with the number of requests and concurrency
DATA_DIR = os.path.join(SCRIPT_DIR, 'data') #Directory where the test results will be saved
MAX_RETRY = 1 #Number of retries in case of test failure
RETRY_DELAY = 10 #Delay between retries

UPLOAD_DATA = True #Flag to upload the test results
COMPRESS_DATA = True #Flag to compress the test results

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
    """
    Class to represent a service to be tested
    """ 
    def __init__(self, name, up_command, down_command, test_url):
        self.name = name
        self.up_command = up_command
        self.down_command = down_command
        self.test_url = test_url

    def get_test_command(self, req, conc, algo):
        """Generate test command to be executed

        Args:
            req (int): number of requests
            conc (int): number of concurrent requests
            algo (string): selected TCP congestion algorithm

        Returns:
            string: test command to be executed
        """
        test_name = self.get_test_name(req, conc, algo)
        test_folder = os.path.join(DATA_DIR, self.name, algo, '{}r{}c'.format(req, conc))
        test_csv = os.path.join(test_folder, '{}.csv'.format(test_name))
        return "ab -n {} -c {} -e \"{}\" {}".format(req, conc, test_csv, self.test_url)

    def get_test_name(self, req, conc, algo):
        """Generate unique test name for the test
        Args:
            req (int): number of requests
            conc (int): number of concurrent requests
            algo (string): selected TCP congestion algorithm
        Returns:
            string: test command to be executed
        """        
        return "{}_cubic_{}_{}r{}c".format(self.name, algo, req, conc)
    
def change_tcp_alg(algo):
    """Change the TCP congestion algorithm to be used on the server

    Args:
        algo (string): TCP congestion algorithm to be used
    """
    run_in_server("sysctl net.ipv4.tcp_congestion_control={}".format(algo))

def shutdown_all_services(services_list):
    """shutdown all services to ensure a clean testing environment

    Args:
        services_list (list): list of services to be stopped
    """
    cmd = ''
    for service in services_list:
        cmd += "{}; ".format(service.down_command)
        run_in_docker(cmd)

def run_in_docker(cmd):
    """Run a command inside a remote Docker container

    Args:
        cmd (string): command line
    """
    docker_cmd = "docker exec {} bash -c \\\"{}\\\"".format(CONTAINER_ID, cmd)
    run_in_server(docker_cmd)

def run_in_server(cmd):
    """Run a command on the server via ssh

    Args:
        cmd (string): command line

    Raises:
        subprocess.CalledProcessError: error running the command

    Returns:
        bytes: output
    """

    full_cmd = "ssh {}@{} -i {} \"{}\"".format(SERVER_USER, SERVER_IP,PRIVATE_KEY_PATH, cmd)
    p = subprocess.Popen(shlex.split(full_cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    if p.returncode != 0:
        raise subprocess.CalledProcessError(p.returncode, full_cmd, output=stdout)
    print(stdout.decode("utf-8"))
    return stdout

def run_local(cmd, out=None):
    """Run a command locally

    Args:
        cmd (string): command line
        out (bytes, optional): output. Defaults to None.

    Raises:
        subprocess.CalledProcessError: error running the command

    Returns:
        bytes: output
    """
    if out is None:
        p = subprocess.Popen(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
            raise subprocess.CalledProcessError(p.returncode, cmd, output=stdout)
        print(stdout.decode("utf-8"))
        return stdout
    else:
        p = subprocess.Popen(shlex.split(cmd), stdout=out, stderr=subprocess.PIPE)
        _, stderr = p.communicate()
        if p.returncode != 0:
            raise subprocess.CalledProcessError(p.returncode, cmd, output="")

def make_dirs(services_list):
    """ Create directories to store test results

    Args:
        services_list (list): list of services to be tested
    """
    for service in services_list:
        for algo in TCP_ALGOS_LIST:
            for test in TESTS_LIST:
                req = test['req']
                conc = test['conc']
                os.makedirs(os.path.join(DATA_DIR, service.name, algo, '{}r{}c'.format(req, conc)), exist_ok=True)

if __name__ == '__main__':
    main()
