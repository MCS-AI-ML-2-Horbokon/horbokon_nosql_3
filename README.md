## Частина 1 — проєктування схеми

### Схема графа

```
(User)
| userId: Integer
| gender: String
| age: Integer
| occupation: Integer
```

```
(Movie)
| movieId: Integer
| title: String
| year: Integer
```

```
(Genre)
| name: String
```

```
(User)-[:RATED]->(Movie)
| rating: Integer
| timestamp: Integer
```

```
(Movie)-[:HAS_GENRE]->(Genre)
```

### 1. Які сутності стали вузлами, а які — ребрами? Чому?

Вузлами стали `User`, `Movie` і `Genre`, тому що це основні сутності предметної області, які можуть мати власні властивості та брати участь у багатьох зв'язках. Користувач має демографічні атрибути, фільм має назву й рік випуску, а жанр є окремою категорією, яку можуть мати багато фільмів.

Ребрами стали `RATED` і `HAS_GENRE`. Зв'язок `RATED` показує дію користувача щодо конкретного фільму й містить властивості цієї дії: оцінку та час. Зв'язок `HAS_GENRE` показує належність фільму до жанру. Така модель добре підходить для графових запитів: можна швидко переходити від користувача до переглянутих фільмів, від фільмів до жанрів, а також знаходити схожих користувачів через спільні оцінки.

### 2. Оцінка користувача за фільм — це ребро `(User)-[:RATED]->(Movie)` чи окремий вузол `Rating`?

У цій роботі оцінка моделюється як ребро `(User)-[:RATED]->(Movie)` із властивостями `rating` і `timestamp`. Це природний варіант, бо оцінка є саме взаємодією між двома сутностями — користувачем і фільмом. Такий підхід робить типові запити коротшими: наприклад, пошук фільмів, які користувач оцінив високо, або пошук користувачів зі схожими оцінками виконується прямим обходом ребер.

Окремий вузол `Rating` мав би сенс, якби оцінка була складною сутністю: наприклад, мала коментарій, історію змін, реакції інших користувачів або кілька незалежних зв'язків з іншими сутностями. Недолік такого підходу для нашого датасету — більше вузлів і довші шляхи: замість одного переходу `User -> Movie` потрібно було б проходити `User -> Rating -> Movie`. Для цих даних це зайве ускладнення.

### 3. Чому жанри фільму вигідніше зберігати як окремі вузли `Genre`, а не як список у властивості вузла `Movie`?

Жанри вигідніше зберігати як окремі вузли, бо жанр — це спільна сутність для багатьох фільмів. Якщо зберігати жанри списком у властивості `Movie`, то для пошуку фільмів певного жанру або для аналізу популярності жанрів доведеться працювати з властивостями. У графовій моделі з вузлами `Genre` такі операції стають обходами графа: `(Movie)-[:HAS_GENRE]->(Genre)`.

Окремі жанрові вузли також корисні для рекомендацій і аналітики. Наприклад, можна знайти улюблені жанри користувача, порівняти жанрові профілі різних користувачів або аналізувати спільноти за жанровими вподобаннями. Крім того, така схема уникає дублювання текстових значень жанрів у багатьох фільмах і робить модель більш нормалізованою.

## Частина 2 — Завантаження даних

### Підготовка CSV-файлів

Файли `movies.dat`, `users.dat` і `ratings.dat` лежать у директорії `import/`. Вони були конвертовані в CSV з кодуванням UTF-8 за допомогою `convert.py`. Скрипт читає початкові файли в кодуванні `latin-1`, розділяє рядки за `::` і створює файли `movies.csv`, `users.csv`, `ratings.csv` у тій самій директорії `import`

Для `users.csv` збережено поля `userId`, `gender`, `age`, `occupation`

Конвертація `.dat` у `.csv`:

```sh
uv run convert.py
```

Результат:

```text
PS C:\Homework\horbokon_nosql_3> uv run convert.py
Converted movies.dat, ratings.dat, users.dat to CSV files in import folder.
3883 movies
1000209 ratings
6040 users
```

### Індекси та обмеження

У `queries/part2_load.cypher` створені унікальні обмеження:

```cypher
CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User)
REQUIRE u.userId IS UNIQUE;

CREATE CONSTRAINT movie_id IF NOT EXISTS
FOR (m:Movie)
REQUIRE m.movieId IS UNIQUE;

CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre)
REQUIRE g.name IS UNIQUE;
```

Вони одночасно гарантують відсутність дублів і створюють індекси для швидкого пошуку вузлів за ключовими властивостями. Це важливо перед завантаженням ребер `RATED`, бо для кожного рядка з `ratings.csv` Neo4j має швидко знайти відповідного користувача та фільм.

### Завантаження вузлів

Користувачі та фільми завантажуються через `LOAD CSV WITH HEADERS`. Для створення вузлів використовується `MERGE`, а не `CREATE`, щоб повторний запуск скрипта не створював дублікати.

Для фільмів рік виділяється з назви, наприклад з `Toy Story (1995)` береться `1995`. Жанри розбиваються через `split(row.genres, '|')`, після чого для кожного жанру створюється або знаходиться вузол `Genre` і зв'язок `(:Movie)-[:HAS_GENRE]->(:Genre)`.

### Завантаження оцінок

Оцінки завантажуються як ребра `(:User)-[:RATED]->(:Movie)` із властивостями `rating` і `timestamp`. Оскільки у файлі понад мільйон оцінок, завантаження виконується через `apoc.periodic.iterate` з `batchSize: 10000`. Це розбиває роботу на менші транзакції та зменшує ризик таймаутів або проблем із пам'яттю.

### Результати

```
PS C:\Homework\horbokon_nosql_3> ./execute.ps1 /queries/part2_load.cypher
usersUpserted
6040
moviesUpserted
3883
genresUpserted, movieGenresUpserted
18, 6408
total, committedOperations, failedOperations
1000209, 1000209, 0
users
6040
movies
3883
genres
18
ratings
1000209
movieGenreLinks
6408
```

## Частина 3 — Запити різної складності

Файл із запитами: `queries/part3.cypher`.

Команда запуску:

```sh
./execute.ps1 /queries/part3.cypher
```

### Базові запити

#### Запит 1. Фільми жанру Thriller із середнім рейтингом вище 4.0

Скрипт:

```cypher
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
```

Результат:

```text
movieId, title, averageRating, ratingsCount
50, "Usual Suspects, The (1995)", 4.52, 1783
745, "Close Shave, A (1995)", 4.52, 657
904, "Rear Window (1954)", 4.48, 1050
1212, "Third Man, The (1949)", 4.45, 480
2762, "Sixth Sense, The (1999)", 4.41, 2459
908, "North by Northwest (1959)", 4.38, 1315
593, "Silence of the Lambs, The (1991)", 4.35, 2578
1252, "Chinatown (1974)", 4.34, 1185
1267, "Manchurian Candidate, The (1962)", 4.33, 765
2571, "Matrix, The (1999)", 4.32, 2590
```

Запит знаходить фільми, пов'язані з вузлом жанру `Thriller`, рахує середню оцінку за всіма ребрами `RATED` і залишає тільки фільми з рейтингом вище `4.0`

#### Запит 2. Користувачі, які поставили оцінку 5 більш ніж 50 фільмам

Скрипт:

```cypher
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
```

Результат:

```text
userId, gender, age, occupation, fiveStarRatings
4277, "M", 35, 16, 571
4169, "M", 50, 0, 476
3032, "M", 25, 0, 466
4448, "M", 25, 14, 434
5100, "M", 50, 6, 424
1680, "M", 25, 20, 406
549, "M", 25, 6, 402
2909, "M", 25, 7, 396
3391, "M", 18, 4, 387
1285, "M", 35, 4, 377
```

Запит проходить від користувачів до оцінених фільмів, залишає тільки ребра з `rating = 5`, групує результат за користувачем і відбирає тих, у кого таких оцінок більше 50.

### Запити середнього рівня

#### Запит 3. Фільми, які користувачі 1 і 2 обидва оцінили високо

Скрипт:

```cypher
MATCH (:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.movieId AS movieId,
       m.title AS title,
       r1.rating AS user1Rating,
       r2.rating AS user2Rating
ORDER BY m.title
LIMIT 10;
```

Результат:

```text
movieId, title, user1Rating, user2Rating
3105, "Awakenings (1990)", 5, 4
1246, "Dead Poets Society (1989)", 4, 5
1962, "Driving Miss Daisy (1989)", 4, 5
1193, "One Flew Over the Cuckoo's Nest (1975)", 5, 5
2028, "Saving Private Ryan (1998)", 5, 4
1207, "To Kill a Mockingbird (1962)", 4, 4
```

Запит шукає спільні фільми для двох конкретних користувачів через шаблон `User -> Movie <- User`. Умова `rating >= 4` означає, що обидва користувачі оцінили ці фільми позитивно.

#### Запит 4. Жанри, чиї фільми стабільно отримують високі оцінки — середній рейтинг і кількість оцінок

Скрипт:

```cypher
MATCH (:User)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WITH g, avg(r.rating) AS averageRating, count(r) AS ratingsCount
WHERE ratingsCount >= 1000
RETURN g.name AS genre,
       round(averageRating, 2) AS averageRating,
       ratingsCount
ORDER BY averageRating DESC, ratingsCount DESC
LIMIT 10;
```

Результат:

```text
genre, averageRating, ratingsCount
"Film-Noir", 4.08, 18261
"Documentary", 3.93, 7910
"War", 3.89, 68527
"Drama", 3.77, 354529
"Crime", 3.71, 79541
"Animation", 3.68, 43293
"Musical", 3.67, 41533
"Mystery", 3.67, 40178
"Western", 3.64, 20683
"Romance", 3.61, 147523
```

Запит агрегує оцінки за жанрами через шлях `User -> Movie -> Genre`. Обмеження `ratingsCount >= 1000` прибирає жанри з надто малою кількістю оцінок, щоб результат був стабільнішим. Найвищий середній рейтинг має `Film-Noir`, але він має значно менше оцінок, ніж, наприклад, `Drama`.

### Складні запити

#### Запит 5. Рекомендація на основі користувачів зі схожими смаками

Рекомендація «користувачі зі схожими смаками також дивилися»: для заданого користувача знайти фільми, які він ще не дивився, але високо оцінили користувачі з подібними смаками

Скрипт:

```cypher
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
```

Результат:

```text
movieId, title, recommendingUsers, averageRatingFromSimilarUsers, maxSharedHighRatedMovies
2858, "American Beauty (1999)", 2307, 4.69, 38
1196, "Star Wars: Episode V - The Empire Strikes Back (1980)", 2250, 4.6, 38
593, "Silence of the Lambs, The (1991)", 2029, 4.6, 38
1198, "Raiders of the Lost Ark (1981)", 2018, 4.68, 38
318, "Shawshank Redemption, The (1994)", 1930, 4.71, 38
2571, "Matrix, The (1999)", 1891, 4.66, 38
1210, "Star Wars: Episode VI - Return of the Jedi (1983)", 1800, 4.49, 38
858, "Godfather, The (1972)", 1736, 4.74, 38
589, "Terminator 2: Judgment Day (1991)", 1709, 4.46, 38
110, "Braveheart (1995)", 1698, 4.61, 38
```

Запит спочатку знаходить користувачів, які мають з користувачем `1` щонайменше 3 спільні високо оцінені фільми. Потім серед фільмів, які ці схожі користувачі оцінили високо, відкидаються ті, які користувач `1` уже оцінював. Рекомендації сортуються за кількістю схожих користувачів, середньою оцінкою від них і максимальною кількістю спільних улюблених фільмів.

#### Запит 6. Найкоротший ланцюжок зв'язку між двома користувачами через спільні фільми

Скрипт:

```cypher
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
```

Результат:

```text
pathLength, pathNodes
2, ["User 1", "Movie Awakenings (1990)", "User 2"]
```

Запит використовує `shortestPath`, щоб знайти найкоротший шлях між двома користувачами через ребра `RATED`. У результаті шлях має довжину `2`, тобто користувачі напряму пов'язані через один спільний фільм.

##### Інтерпретація довжини шляху

Довжина шляху в цьому графі означає кількість ребер `RATED`, які потрібно пройти, щоб перейти від одного користувача до іншого через фільми. Оскільки модель двочасткова для користувачів і фільмів, шлях між двома користувачами зазвичай має парну довжину: `User -> Movie -> User -> Movie -> User`.

Шлях довжини `2` означає, що два користувачі оцінили один і той самий фільм. У нашому результаті користувачі `1` і `2` обидва оцінили фільм `Awakenings (1990)`.

Шлях довжини `4` означає, що між двома користувачами є один проміжний користувач: перший користувач має спільний фільм з проміжним, а проміжний має інший спільний фільм з другим користувачем. Шлях довжини `6` означає вже два проміжні користувачі та три фільми-зв'язки між ними. Чим довший шлях, тим слабший і менш прямий зв'язок між користувачами.
