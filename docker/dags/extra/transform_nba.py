import sys
from pyspark import SparkConf, SparkContext
from pyspark.sql import functions as F

TABLE = "player_boxstats"


def main():
    host = F"c-{sys.argv[1]}.rw.mdb.yandexcloud.net"
    port = 8123
    db = sys.argv[2]
    user = sys.argv[3]
    password = sys.argv[4]
    data_bucket = F"s3a://{sys.argv[5]}/"

    url = F"jdbc:clickhouse://{host}:{port}/{db}"

    conf = SparkConf().setAppName("NBA data processing")
    sc = SparkContext(conf=conf)

    # load player_info
    col = ["playerName", "From", "To", "birthDate"]

    df = sc.read.format("parquet") \
        .option("header", True) \
        .load(data_bucket + "player_info.parquet") \
        .select(col)

    # type conversion & column rename
    df = df \
        .withColumn("playerName", F.regexp_replace(
            df.playerName, "\*", "").cast("string")) \
        .withColumn("From", df.From.cast("integer")) \
        .withColumn("To", df.To.cast("integer")) \
        .withColumn("birthDate", F.to_date(df.birthDate, "MMMM dd, yyyy")) \
        .withColumnRenamed("playerName", "player") \
        .withColumnRenamed("From", "career_start") \
        .withColumnRenamed("To", "career_end") \
        .withColumnRenamed("birthDate", "birth_date") \
        .dropDuplicates(subset=["player"]) \
        .filter(df.birthDate.isNotNull())

    # data transformations
    df = df \
        .withColumn("career_duration",
            df.career_end - df.career_start) \
        .withColumn("career_start_age",
            df.career_start - F.year(df.birth_date)) \
        .withColumn("career_end_age",
            df.career_end - F.year(df.birth_date))


    # read boxscore data
    col = [
        "game_id", "teamName", "playerName",
        "MP", "FG", "FGA", "3P", "3PA",
        "FT", "FTA", "PTS"
    ]
    
    filter_values = [
        "Did Not Dress", "Player Suspended",
        "Did Not Play", "Not With Team"
    ]

    bx = sc.read.format("parquet") \
        .option("header", True) \
        .load(data_bucket + "boxscore.parquet") \
        .select(col)

    # type conversion & column rename
    bx = bx \
        .filter(~bx.MP.isin(filter_values)) \
        .withColumn("game_id", bx.game_id.cast("integer")) \
        .withColumn("teamName", bx.teamName.cast("string")) \
        .withColumn("playerName", bx.playerName.cast("string")) \
        .withColumn("FG", bx.FG.cast("integer")) \
        .withColumn("FGA", bx.FGA.cast("integer")) \
        .withColumn("3P", bx["3P"].cast("integer")) \
        .withColumn("3PA", bx["3PA"].cast("integer")) \
        .withColumn("FT", bx.FT.cast("integer")) \
        .withColumn("FTA", bx.FTA.cast("integer")) \
        .withColumn("PTS", bx.PTS.cast("integer")) \
        .withColumn("minutes_played",
            F.regexp_extract(bx.MP, "^(\d+):", 1).cast("float") +
            F.regexp_extract(bx.MP, ":(\d+)$", 1).cast("float") / 60) \
        .withColumnRenamed("teamName", "team") \
        .withColumnRenamed("playerName", "player") \
        .select(
            "game_id", "team", "player", "minutes_played",
            "FG", "FGA", "3P", "3PA", "FT", "FTA", "PTS")

    # join boxscore with player info
    df = bx.join(df, how="left", on=["player"])

    # write to Clickhouse
    df.write.format("jdbc") \
        .mode("error") \
        .option("url", url) \
        .option("dbtable", TABLE) \
        .option("createTableOptions",
            "ENGINE = MergeTree() PARTITION BY team ORDER BY PTS DESC") \
        .option("user", user) \
        .option("password", password) \
        .save()

    if __name__ == "__main__":
        main()
