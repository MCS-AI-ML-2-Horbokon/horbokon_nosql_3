param(
    [string]$path
)

docker exec neo4j_movielens cypher-shell -u neo4j -p password123 -f $path
