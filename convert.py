import csv
from pathlib import Path

IMPORT_DIR = Path("import")
INPUT_ENCODING = "latin-1"
OUTPUT_ENCODING = "utf-8"


def convert_movies() -> int:
    with (
        (IMPORT_DIR / "movies.dat").open(encoding=INPUT_ENCODING) as f_in,
        (IMPORT_DIR / "movies.csv").open("w", newline="", encoding=OUTPUT_ENCODING) as f_out
    ):
        writer = csv.writer(f_out)
        writer.writerow(["movieId", "title", "genres"])
        count = 0
        for line in f_in:
            writer.writerow(line.rstrip("\n").split("::"))
            count += 1

        return count


def convert_ratings() -> int:
    with (
        (IMPORT_DIR / "ratings.dat").open(encoding=INPUT_ENCODING) as f_in,
        (IMPORT_DIR / "ratings.csv").open("w", newline="", encoding=OUTPUT_ENCODING) as f_out
    ):
        writer = csv.writer(f_out)
        writer.writerow(["userId", "movieId", "rating", "timestamp"])
        count = 0
        for line in f_in:
            writer.writerow(line.rstrip("\n").split("::"))
            count += 1

        return count


def convert_users() -> int:
    with (
        (IMPORT_DIR / "users.dat").open(encoding=INPUT_ENCODING) as f_in,
        (IMPORT_DIR / "users.csv").open("w", newline="", encoding=OUTPUT_ENCODING) as f_out
    ):
        writer = csv.writer(f_out)
        writer.writerow(["userId", "gender", "age", "occupation"])
        count = 0
        for line in f_in:
            writer.writerow(line.rstrip("\n").split("::")[:4])
            count += 1

        return count


def main() -> None:
    movies_count = convert_movies()
    ratings_count = convert_ratings()
    users_count = convert_users()
    print("Converted movies.dat, ratings.dat, users.dat to CSV files in import folder.")
    print(f"{movies_count} movies")
    print(f"{ratings_count} ratings")
    print(f"{users_count} users")


if __name__ == "__main__":
    main()
