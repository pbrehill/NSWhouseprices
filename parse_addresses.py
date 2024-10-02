import pandas as pd
import argparse
from addressnet.predict import predict

def predict_addresses(addresses):
  parsed_addresses = predict(addresses)
  df = pd.DataFrame(parsed_addresses)
  df.to_csv('parsed_addresses.csv', index=False)


if __name__ == '__main__':
  with open("addresses.txt", "r") as file:
  # Read each line, strip any trailing newline characters, and store them in a list
    addresses = [line.strip() for line in file]

  # Parse addresses and export to CSV
  parsed_addresses = parse_addresses(addresses)
  print(f"Parsed addresses saved to parsed_addresses.csv")
