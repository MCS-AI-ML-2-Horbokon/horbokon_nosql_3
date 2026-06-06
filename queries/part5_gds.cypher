RETURN '5.1 PageRank on movie co-rating graph' AS section;

MATCH ()-[co:CO_RATED]-()
DELETE co;

CALL gds.graph.drop('movieGraph', false) YIELD graphName AS droppedGraphName
RETURN coalesce(droppedGraphName, 'No existing projection') AS projectionStatus;

MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight
RETURN count(co) AS coRatedRelationshipsCreated;

CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

CALL gds.pageRank.stream('movieGraph', {
  relationshipWeightProperty: 'weight',
  maxIterations: 20,
  dampingFactor: 0.85
})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS movie, score
RETURN movie.movieId AS movieId,
       movie.title AS title,
       round(score, 4) AS pageRankScore
ORDER BY score DESC
LIMIT 10;

CALL gds.graph.drop('movieGraph') YIELD graphName
RETURN graphName AS droppedGraphName;

MATCH ()-[co:CO_RATED]-()
DELETE co;

RETURN '5.2 Louvain communities on user similarity graph' AS section;

MATCH (u:SimilarUser)
REMOVE u:SimilarUser;

MATCH (u:User)
REMOVE u.communityId;

MATCH ()-[sim:SIMILAR]-()
DELETE sim;

CALL gds.graph.drop('userSimilarity', false) YIELD graphName AS droppedGraphName
RETURN coalesce(droppedGraphName, 'No existing projection') AS projectionStatus;

MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating = 5 AND r2.rating = 5 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight,
    sim.cost = 1.0 / weight
RETURN count(sim) AS similarRelationshipsCreated;

MATCH (u:User)-[:SIMILAR]-()
SET u:SimilarUser
RETURN count(DISTINCT u) AS usersInSimilarityGraph;

CALL gds.graph.project(
  'userSimilarity',
  'SimilarUser',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: ['weight', 'cost'] } }
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

CALL gds.louvain.write('userSimilarity', {
  relationshipWeightProperty: 'weight',
  writeProperty: 'communityId'
})
YIELD communityCount, modularity, modularities
RETURN communityCount, round(modularity, 4) AS modularity;

MATCH (u:SimilarUser)
WHERE u.communityId IS NOT NULL
RETURN u.communityId AS communityId,
       count(u) AS usersCount
ORDER BY usersCount DESC
LIMIT 10;

MATCH (u:SimilarUser)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS communityId, count(u) AS usersCount
ORDER BY usersCount DESC
LIMIT 5
MATCH (:User {communityId: communityId})-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, usersCount, g.name AS genre, count(*) AS genreLikes
ORDER BY communityId, genreLikes DESC
WITH communityId, usersCount, collect({genre: genre, likes: genreLikes})[0..3] AS topGenres
RETURN communityId, usersCount, topGenres
ORDER BY usersCount DESC;

RETURN '5.3 Dijkstra shortest paths between users on similarity graph' AS section;

CALL gds.graph.drop('userGraph', false) YIELD graphName AS droppedGraphName
RETURN coalesce(droppedGraphName, 'No existing projection') AS projectionStatus;

CALL gds.graph.project(
  'userGraph',
  'SimilarUser',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: ['weight', 'cost'] } }
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;

MATCH (source:User {userId: 4169}), (target:User {userId: 1680})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: id(source),
  targetNode: id(target),
  relationshipWeightProperty: 'cost'
})
YIELD totalCost, nodeIds, costs
RETURN source.userId AS sourceUserId,
       target.userId AS targetUserId,
       round(totalCost, 4) AS totalCost,
       size(nodeIds) - 1 AS pathLength,
       [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS pathUsers;

MATCH (source:User {userId: 4277}), (target:User {userId: 1941})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: id(source),
  targetNode: id(target),
  relationshipWeightProperty: 'cost'
})
YIELD totalCost, nodeIds, costs
RETURN source.userId AS sourceUserId,
       target.userId AS targetUserId,
       round(totalCost, 4) AS totalCost,
       size(nodeIds) - 1 AS pathLength,
       [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS pathUsers;

MATCH (source:User {userId: 4169}), (target:User {userId: 4277})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: id(source),
  targetNode: id(target),
  relationshipWeightProperty: 'cost'
})
YIELD totalCost, nodeIds, costs
RETURN source.userId AS sourceUserId,
       target.userId AS targetUserId,
       round(totalCost, 4) AS totalCost,
       size(nodeIds) - 1 AS pathLength,
       [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS pathUsers;

CALL gds.graph.drop('userGraph') YIELD graphName
RETURN graphName AS droppedGraphName;

CALL gds.graph.drop('userSimilarity') YIELD graphName
RETURN graphName AS droppedGraphName;

MATCH ()-[sim:SIMILAR]-()
DELETE sim;

MATCH (u:SimilarUser)
REMOVE u:SimilarUser;
