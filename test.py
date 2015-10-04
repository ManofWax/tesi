from ChatManager import *
from twokenizer import *
import logging
from Twitch import Emotes
__author__ = 'wax'

path = '../TwitchCorpora/'
file_in = 'destiny.txt'
file_out = 'destiny2.txt'

logging.basicConfig(level=logging.DEBUG)
#kripp = ChatCorpus(path,file_out)
file = "../TwitchCorpora/destiny2.txt"
c = ChatCorpus("",file)
c.ExtractEmoticons()
#destinyChat = ChatManager(path + file_in)
#destinyChat.process_file()
#destinyChat.print_statistics()
#Emotes.print_global_emotes(destinyChat.processedFile)
#destinyChat.save(path + file_out)
