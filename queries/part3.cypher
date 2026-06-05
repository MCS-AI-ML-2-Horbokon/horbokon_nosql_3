RETURN 'Query 1: Thriller movies with average rating above 4.0' AS query;

MATCH (m:Movie)-[:HAS_GENRE]->(:Genre {name: 'Thriller'})
MATCH (m)<-[r:RATED]-(:User)
WITH m, avg(r.rating) AS averageRating, count(r) AS ratingsCount
WHERE averageRating > 4.0
RETURN m.movieId AS movieId,
       m.title AS title,
       round(averageRating, 2) AS averageRating,
       ratingsCount
ORDER BY averageRating DESC, ratingsCount DESC
LIMIT 10;

RETURN 'Query 2: Users who gave rating 5 to more than 50 movies' AS query;

MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5
WITH u, count(r) AS fiveStarRatings
WHERE fiveStarRatings > 50
RETURN u.userId AS userId,
       u.gender AS gender,
       u.age AS age,
       u.occupation AS occupation,
       fiveStarRatings
ORDER BY fiveStarRatings DESC
LIMIT 10;

RETURN 'Query 3: Movies highly rated by both user 1 and user 2' AS query;

MATCH (:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.movieId AS movieId,
       m.title AS title,
       r1.rating AS user1Rating,
       r2.rating AS user2Rating
ORDER BY m.title
LIMIT 10;

RETURN 'Query 4: Genres with stable high ratings' AS query;

MATCH (:User)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WITH g, avg(r.rating) AS averageRating, count(r) AS ratingsCount
WHERE ratingsCount >= 1000
RETURN g.name AS genre,
       round(averageRating, 2) AS averageRating,
       ratingsCount
ORDER BY averageRating DESC, ratingsCount DESC
LIMIT 10;

RETURN 'Query 5: Recommendations for user 1 from users with similar tastes' AS query;

MATCH (target:User {userId: 1})-[targetRating:RATED]->(shared:Movie)<-[similarRating:RATED]-(similarUser:User)
WHERE targetRating.rating >= 4
  AND similarRating.rating >= 4
  AND target <> similarUser
WITH target, similarUser, count(shared) AS sharedHighRatedMovies
WHERE sharedHighRatedMovies >= 3
MATCH (similarUser)-[recRating:RATED]->(recommended:Movie)
WHERE recRating.rating >= 4
  AND NOT EXISTS {
    MATCH (target)-[:RATED]->(recommended)
  }
WITH recommended,
     count(DISTINCT similarUser) AS recommendingUsers,
     avg(recRating.rating) AS averageRatingFromSimilarUsers,
     max(sharedHighRatedMovies) AS maxSharedHighRatedMovies
RETURN recommended.movieId AS movieId,
       recommended.title AS title,
       recommendingUsers,
       round(averageRatingFromSimilarUsers, 2) AS averageRatingFromSimilarUsers,
       maxSharedHighRatedMovies
ORDER BY recommendingUsers DESC, averageRatingFromSimilarUsers DESC, maxSharedHighRatedMovies DESC
LIMIT 10;

RETURN 'Query 6: Shortest connection chain between user 1 and user 2 through shared movies' AS query;

MATCH path = shortestPath((u1:User {userId: 1})-[:RATED*..6]-(u2:User {userId: 2}))
RETURN length(path) AS pathLength,
    [
        node IN nodes(path) |
        CASE
          WHEN node:User THEN 'User ' + toString(node.userId)
          WHEN node:Movie THEN 'Movie ' + node.title
          ELSE labels(node)[0]
        END
    ] AS pathNodes;
