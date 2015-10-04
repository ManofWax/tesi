__author__ = 'wax'
import re
import nltk
import logging
import time
import os

class ChatCorpus:
    """
    Handle processed chat files like a corpus
    """
    def __init__(self, file_directory_path, file_name):
        #self.wordlists = nltk.PlaintextCorpusReader(file_directory_path, file_extension)
        self.filename = file_name
        file = open(file_name, encoding="utf8")
        self.file_txt = file.read()
        file.close()

    def ExtractEmoticons(self):
        kappa = re.compile(".*Kappa.*\n")
        file_kappa = " ".join(re.findall(kappa, self.file_txt))
        file = open(self.filename + "Kappa",mode='w', encoding="utf8")
        file.write(file_kappa)
        file.close()

class ChatManager:
    """
    Process raw files and save them
    """
    def __init__(self, file_path):
        self.filePath = file_path
        self.processedFile = ""
        file = open(file_path, encoding="utf8")
        self.rawFile = file.read()
        self.nonAsciiLines = ""
        file.close()

    def process_file(self):
        """
        Remove shit from the raw file
        :return:
        """
        rep = re.compile(r"""
                        http[s]?://.*?[\s|\n]
                        |www.*?[\s|\n]
                        |(\n){2,}
                        """, re.X)
        non_asc = re.compile(".*[^\x00-\x7F].*\n")
        start_time = time.time()
        logging.debug("Start file processing")
        self.processedFile = re.sub(rep, "", self.rawFile)
        self.processedFile = re.sub(non_asc, "", self.processedFile)
        end_time = time.time()
        logging.debug("Processed file in " + str(end_time - start_time))
        start_time = time.time()
        logging.debug("Start finding non-ASCII lines")
        self.nonAsciiLines = " ".join(re.findall(non_asc, self.rawFile))
        end_time = time.time()
        logging.debug("Lines found in " + str(end_time - start_time))

    def print_statistics(self):
        print("Original file lenght:{} \n Processed file lenght:{}\n NonAscii lenght: {}".format(len(self.rawFile), len(self.processedFile), len(self.nonAsciiLines)))

    def save(self, file_path):
        """
        Save the processed file
        :param file_path: the save path
        :return:
        """
        file = open(file_path, mode='w', encoding="utf8")
        file.write(self.processedFile)
        logging.debug("Saved file " + file_path)
        file.close()
        file = open(file_path + "notAscii", mode='w', encoding="utf8")
        file.write(self.nonAsciiLines)
        logging.debug("Saved file 2")
        file.close()

class ChatLive:
    """Classe di analisi del testo per le chat live"""
    def __index__(self):
        pass