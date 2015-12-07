from textblob import TextBlob

with  open('input.txt','r') as fin, open('diversi.txt','w') as fout, open('spam.txt','w') as spam:
    for lines in fin:
        try:
            text = TextBlob(lines)
            error = 0
            # if more than 70% of words contains the same word discard the line
            for x,y in text.word_counts.items():
                if y > 4:
                    error = 1
                    break

            if error == 1:
                spam.writelines(lines)
            else:
                fout.writelines(lines)
        except Exception:
            print("Errore" + lines)