from config import BASE_URL
from fetcher import fetch_data
from printer import print_data


# Since it is sequential, no need for asyncio
def main():
    # Step 1: Fetch data from compliance API
    raw_data = fetch_data(BASE_URL)

    # Step 2: Print the normalized data in a readable format
    print_data(raw_data)
    
if __name__ == "__main__":
    main()