# -*- coding:utf-8 -*-
import urllib2
import json
import sys
import getopt
import os

# connection info
WEBCACHE_SERVER = "10.165.124.46"
PORT = 8080

# appInfo
NATIVE_APP = "kaola"
NATIVE_VERSION = "1.0.0"
PLATFORM = "ios"
WEBAPPINFO_FOLDER = "/CandyWebCache"
WEBAPPINFO_CONFIG = "/WebappInfo.json"

SUCCESS = 200
ERR_PROTOCOL = 401
ERR_APPID = 402
ERR_SERVER = 501
ERR_UNKNOWN = 601

class CandyWebcacheBuilder:
    webcache_server = ""
    port = 0
    download_path = ""

    def __init__(self, webcache_server, port, path):
        self.webcache_server = webcache_server
        self.port = port
        if len(path) == 0:
            self.download_path = '%s%s' % (sys.path[0], WEBAPPINFO_FOLDER)
        else:
            self.download_path = '%s%s' % (path, WEBAPPINFO_FOLDER)
        if not os.path.exists(self.download_path):
            os.mkdir(self.download_path)
            print self.download_path + 'create successfully'
        print self.download_path

    """
    @return (err_msg, url)
    """
    @property
    def getWebappInfo(self):
        webapp_downloadInfo = []
        request_body = {
                          "version": "0.1",
                          "appID": NATIVE_APP,
                          "appVersion": NATIVE_VERSION,
                          "platform": PLATFORM,
                          "isDiff": False,
                          "autoFill": True
                        }
        req = urllib2.Request('http://%s:%s/api/version_check/webapp' % (self.webcache_server, str(self.port)))
        req.add_header('Content-Type', 'application/json')
        webapp_fullurls = []
        try:
            # adopt default timeout
            response_data = urllib2.urlopen(req, json.dumps(request_body)).read()
        except urllib2.HTTPError, e:
            print "Builder error : %s" % str(e.reason)
            sys.exit(1)
        except urllib2.URLError, e:
            print "Builder error : %s" % str(e.reason)
            sys.exit(1)
        else:
            json_data = json.loads(response_data)
            result_code = json_data["code"]
            if result_code == SUCCESS:
                # if success, then write appinfo into config file
                appversion_infos = json_data["data"]["resInfos"]
                json_file = open('%s%s' % (self.download_path, WEBAPPINFO_CONFIG), 'wb')
                json_file.write(json.dumps(json_data["data"]))
                try:
                    for appversion_info in appversion_infos:
                        full_url = appversion_info["fullUrl"]
                        app_id = appversion_info["resID"]
                        file_name = '%s%s' % (app_id, ".zip")
                        if len(full_url) and full_url is not None:
                            webapp_downloadInfo.append([full_url, file_name])
                    if len(webapp_downloadInfo) == 0:
                        sys.exit(0)
                    else:
                        return webapp_downloadInfo
                except Exception, e:
                    print "Builder error(json parse error) : %s" % str(e)
                    sys.exit(1)
            elif result_code == ERR_APPID:
                err_msg = "Invalid appID"
                print "Builder error : %s" % err_msg
                sys.exit(1)
            elif result_code == ERR_PROTOCOL:
                err_msg = "not supported protocol"
                print "Builder error : %s" % err_msg
                sys.exit(1)
            elif result_code == ERR_SERVER:
                err_msg = "Server error"
                print "Builder error : %s" % err_msg
                sys.exit(1)
            else:
                err_msg = "Unknown error"
                print "Builder error : %s" % err_msg
                sys.exit(1)

    '''
    @param url downloadurl
    @return (BOOL, err_msg) (download success/failed, err_msg)
    '''
    def getFile(self, url, file_name):
        try:
            u = urllib2.urlopen(url)
        except urllib2.HTTPError, e:
            print "Builder error : %s" % e.reason
            sys.exit(1)
        except urllib2.URLError, e:
            print "Builder error : %s" % e.reason
            sys.exit(1)
        else:
            f = open('%s/%s' % (self.download_path, file_name), 'wb')
            # comment progress part
            # meta = u.info()
            # file_size = int(meta.getheaders("Content-Length")[0])
            # print "Downloading: %s Bytes: %s" % (file_name, file_size)

            file_size_dl = 0
            block_sz = 8192
            while True:
                buffer = u.read(block_sz)
                if not buffer:
                    break

                file_size_dl += len(buffer)
                f.write(buffer)
                # status = r" %10d  [%3.2f%%]" % (file_size_dl, file_size_dl * 100. / file_size)
                # status = status + chr(8)*(len(status)+1)
                # print status,

            f.close()
            print "Builder Success"


'''
The API exposed to outside.
@return (BOOL, err_msg), (Build success or failed, err_msg)
'''


def candyWebcacheBuilder(host, port, path):
    webcache_builder = CandyWebcacheBuilder(host, port, path)
    webapp_downloadInfos = webcache_builder.getWebappInfo
    print webapp_downloadInfos
    for [url, file_name] in webapp_downloadInfos:
        webcache_builder.getFile(url, file_name)


def get_path_from_commandline_args():
    try:
        optlist, args = getopt.getopt(sys.argv[1:], "b: p:")
        if len(optlist) != 2:
            print "invalid parameters: script -b build_products_dir -p product_name"
            sys.exit(1)

        for opt, value in optlist:
            if opt == '-b':
                build_products_dir = value
            elif opt == '-p':
                product_name = value

        path = '%s/%s' % (build_products_dir, product_name)
        print path
        return path
    except getopt.GetoptError as err:
        print "error: %s" % (str(err))
        sys.exit(1)


if __name__ == "__main__":
    path = get_path_from_commandline_args()
    candyWebcacheBuilder(WEBCACHE_SERVER, PORT, path)
