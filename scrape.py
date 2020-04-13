import datetime
import requests
import os.path
from bs4 import BeautifulSoup
import csv
import os
import turicreate as tc
            
def rebuild_history():
    with open("archive.csv") as csv_file:
        reader = csv.reader(csv_file, delimiter=',')
        with open('history.csv', mode='w') as out_file:
            day = datetime.date.today() - datetime.timedelta(days=1)
            
            writer = csv.writer(out_file, delimiter=',')
            writeheader = True
            for row in reader:
                urlfmt = day.strftime("%b %d, %Y")
                if not writeheader:
                    row[0] = urlfmt
                else:
                    writeheader = False
                writer.writerow(row)
                day = day - datetime.timedelta(days=1)

    
def date_format(day):
    return day.strftime("%b %d, %Y")

def get_today():
    
    # urlfmt = yesterday.strftime("%Y%m%d")
    # 
    # print(hfmt)
    daystoupdate, mostrecentdata = most_recent_data()
    
    
    iterateRow(results)

def fetchFrom(i):
    end = datetime.date.today() - datetime.timedelta(days=2)
    start = datetime.date.today() - datetime.timedelta(days=(i))
    url = "https://coinmarketcap.com/currencies/ethereum/historical-data/?start=" + start.strftime("%Y%m%d") + "&end=" + end.strftime("%Y%m%d")
    page = requests.get(url)
    print(url)
    soup = BeautifulSoup(page.content, 'html.parser')
    results = soup.find_all('tr',class_='cmc-table-row')
    temp = []
    for elem in results:
        td = elem.find_all('td')
        row = [i.text for i in td]
        temp.append(row)
    return temp

def stringToFloat(string):
    if type(string) is float:
        return string
    return float(string.replace(",",""))

def calculate_change(row, previous=None):
    i_open = stringToFloat(row[1])
    i_close = stringToFloat(row[2])
    i_volume = stringToFloat(row[3])
    i_cap = stringToFloat(row[4])
    if previous is not None:
        previous_open = stringToFloat(previous[1])
        previous_volume = stringToFloat(previous[3])
        previous_cap = stringToFloat(previous[4])
        open_change = round(((i_open - previous_open) / previous_open),5)
        volume_change = round(((i_volume - previous_volume) / previous_volume),5)
        cap_change = round(((i_cap - previous_cap) / previous_cap),5)
        return [row[0],i_open,i_close,i_volume,i_cap,open_change,volume_change,cap_change]
    return [row[0],i_open,i_close,i_volume,i_cap]

def parse_fetched(row):
    return [row[0], row[1], row[4], row[5], row[6]]
        # [0] = date
        # [1] = open
        # [4] = close
        # [5] = volume
        # [6] = cap

def train():
    data =  tc.SFrame.read_csv('history.csv')
    data = data.remove_column("date")
    data = data.remove_column("volume")
    # Make a train-test split
    train_data, test_data = data.random_split(0.8)

    # Create a model.
    model = tc.boosted_trees_regression.create(train_data, target='close',
                                            max_iterations=10,
                                            max_depth =  3)

    # Save predictions to an SArray
    predictions = model.predict(test_data)

    # Evaluate the model and save the results into a dictionary
    results = model.evaluate(test_data)
    model.export_coreml('latest.mlmodel')

def get_updates():
    update_made = False
    temp_csv_file = open('temp.csv',mode='wb')
    csv_file = open("history.csv")
    try:
        writer = csv.writer(temp_csv_file, delimiter=',')
        day = datetime.date.today() - datetime.timedelta(days=1)
        reader = csv.reader(csv_file, delimiter=',')
        header = next(reader)
        writer.writerow(header)
        try:
            current_day = next(reader)
        except StopIteration:
            return
        caughtup = False
        rowsToUpdate = 0
        while not caughtup:
            dfm = date_format(day)
            if dfm != current_day[0]:
                print(dfm)
                rowsToUpdate+=1
            else:
                caughtup = True
                break
            day = day - datetime.timedelta(days=1)
        if rowsToUpdate > 0:
            update_made = True
            new_data = fetchFrom(rowsToUpdate)
            temps_rows = []
            rowsToUpdate-=1
            previous = current_day
            iterator = parse_fetched(new_data[rowsToUpdate])
            while rowsToUpdate > 0:
                parsed = calculate_change(iterator, previous)
                print(parsed)
                temps_rows.insert(0,parsed)
                previous = parsed
                rowsToUpdate-=1
                iterator = parse_fetched(new_data[rowsToUpdate])
            parsed = calculate_change(iterator, previous)
            writer.writerow(parsed)
            for new_row in temps_rows:
                writer.writerow(new_row)
            writer.writerow(current_day)
            for row in reader:
                writer.writerow(row)
    finally:
        temp_csv_file.close()
        csv_file.close()
        os.remove("history.csv")
        os.rename("temp.csv","history.csv")
        if update_made:
            train()
            print("Model Updated")

get_updates()