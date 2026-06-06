RETURN 'Top nodes by total degree' AS query;

MATCH (n)
WITH n, count { (n)--() } AS degree
RETURN labels(n)[0] AS label,
       coalesce(n.title, n.name, toString(n.userId)) AS node,
       degree
ORDER BY degree DESC
LIMIT 10;

RETURN 'Top movies by number of ratings' AS query;

MATCH (m:Movie)<-[r:RATED]-(:User)
RETURN m.movieId AS movieId,
       m.title AS title,
       count(r) AS ratingsCount
ORDER BY ratingsCount DESC
LIMIT 10;

RETURN 'Top users by number of ratings' AS query;

MATCH (u:User)-[r:RATED]->(:Movie)
RETURN u.userId AS userId,
       u.gender AS gender,
       u.age AS age,
       u.occupation AS occupation,
       count(r) AS ratingsCount
ORDER BY ratingsCount DESC
LIMIT 10;

RETURN 'Top genres by number of connected movies' AS query;

MATCH (g:Genre)<-[hg:HAS_GENRE]-(m:Movie)
RETURN g.name AS genre,
       count(hg) AS moviesCount
ORDER BY moviesCount DESC
LIMIT 10;
