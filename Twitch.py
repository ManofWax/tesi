import re
__author__ = 'wax'


class Emotes:
    """
    Do shit with the emoticons
    I don't know why I made the method static
    """
    standard_emotes = [l.strip('\n') for l in open('standard_emotes.txt')]
    """Standard emotes are :( :P :D etc."""
    global_emotes = [l.strip('\n') for l in open('global_emotes.txt')]
    """Global emotes are Kappa Pogchamp etc."""
    subscriber_emotes = [l.strip('\n') for l in open('subscriber_emotes.txt')]
    """these are special emotes created by the streamer. There are a shit tone of those I don't thing
    they are useful"""

    def all_emotes(text):
        """Should return all the emoticons containet in text"""
        pass

    def print_global_emotes(text):
        """Print the number of each global emoticon in text"""
        for e in Emotes.global_emotes:
            tmp = re.findall(e, text)
            print("{} : {}".format(e, len(tmp)))
