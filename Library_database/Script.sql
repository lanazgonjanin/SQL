-- Query 1

SELECT book.id, COUNT(DISTINCT bookcopy.id) AS ncopies, COUNT(loan.copy_id) AS nloans, MAX(bookcopy.date) AS newest
FROM book JOIN bookcopy ON book.id = bookcopy.book_id LEFT JOIN loan ON bookcopy.id = loan.copy_id
GROUP BY book.id;

-- Clarifications:
-- We get ncopies (total number of copies of a book) by counting the occurences of each book are in BookCopy
-- Inner join Book and BookCopy since we assume each book has a physical copy
-- We get nloans (total number times a copy has been loaned) by counting the occurences of each copy in Loan
-- Left join BookCopy and Loan to ensure copies that haven't been loaned are accounted for
-- We get newest (date at which the newest copy was bought) by returning the max value of Date in BookCopy
-- All tables are grouped by each book so that when we apply Count and Max, we are applying it for each book


-- Query 2

WITH booksread AS (
    SELECT DISTINCT loan.customer_id AS customer_id, bookcopy.book_id AS book_id
    FROM loan JOIN bookcopy ON loan.copy_id = bookcopy.id
),
booksnotread AS (
	SELECT DISTINCT loan.customer_id AS customer_id, book.id AS book_id
	FROM loan CROSS JOIN book  -- get the cross product of all customers and books
	LEFT JOIN booksread ON loan.customer_id = booksread.customer_id AND book.id = booksread.book_id  -- join BooksRead table to cross product table (preserving records in the left table)
	WHERE booksread.book_id IS NULL  -- only get rows where the book has not been read
	ORDER BY loan.customer_id, book.id  -- order by customer_id, and then by book.id within each customer
),
cdpairs AS (
	SELECT C.customer_id AS customer_c, D.customer_id AS customer_d
	FROM booksread AS C JOIN booksread AS D ON C.book_id = D.book_id  -- join two copies of BooksRead on book_id (one for customer C and one for D)
	WHERE C.customer_id != D.customer_id  -- only get the rows where the customer C is not the same as customer D
	GROUP BY C.customer_id, D.customer_id
	HAVING COUNT(DISTINCT C.book_id) = (SELECT COUNT(DISTINCT book_id) FROM booksread WHERE customer_id = C.customer_id)  -- check that books C has read is same as books D has read
	ORDER BY C.customer_id, D.customer_id   -- order by customer C, and then by customer D within each customer C
)
SELECT DISTINCT booksnotread.customer_id, booksnotread.book_id
FROM booksnotread
JOIN cdpairs ON booksnotread.customer_id = cdpairs.customer_c  -- join by matching customer C to the books they haven't read
JOIN booksread AS D ON booksnotread.book_id = D.book_id  -- make sure that customer D has read the book that C hasn't
WHERE cdpairs.customer_d = D.customer_id  -- make sure that D has read the book that C might be interested in
ORDER BY booksnotread.customer_id, booksnotread.book_id;  -- order by customer, and then by book within each customer

-- Clarifications:
-- BooksRead stores all the books that each customer has read
-- BooksNotRead stores all the books that each customer has not read
-- CDPairs stores the customer ID pairs (C,D) where customer D has read all books that customer C has read


-- Query 3

WITH customeravgscores AS (
    SELECT R1.customer_id, R1.book_id AS book_id, R1.score AS review_score, R1.when AS review_date, AVG(CAST(R2.score AS FLOAT)) AS avg_before_review
	FROM review AS R1 JOIN review AS R2 ON R1.customer_id = R2.customer_id
	WHERE R2.when < R1.when  -- only get the reviews that occured before the given review
	GROUP BY R1.book_id, R1.customer_id, R1.when, R1.score
),
customerreviewcounts AS (
    SELECT A.customer_id, A.book_id AS book_id,
           SUM(CASE WHEN A.review_score > A.avg_before_review THEN 1 ELSE 0 END) AS positive_reviews,  -- count the number of reviews where the score is greater than the avg score before it
           SUM(CASE WHEN A.review_score <= A.avg_before_review THEN 1 ELSE 0 END) AS nonpositive_reviews  -- count the number of reviews where the score is less than or equal to the avg score before it
    FROM customeravgscores AS A
    GROUP BY A.customer_id, A.book_id
),
bookreviewcounts AS (
    SELECT C.book_id AS book_id,
           SUM(C.positive_reviews) AS total_positive_reviews,  -- find the total number of positive reviews for the given book
           SUM(C.nonpositive_reviews) AS total_nonpositive_reviews  -- find the total number of non positive reviews for the given book
    FROM customerreviewcounts AS C
    GROUP BY C.book_id
)
SELECT B.book_id
FROM bookreviewcounts AS B
WHERE B.total_positive_reviews > B.total_nonpositive_reviews;

-- Clarifications:
-- CustomerAvgScores stores all the average scores of reviews by each customer before a given review (the given review is indicated by review_date and review_score)
-- CustomerReviewCounts stores the number of positive and non positive reviews by each customer for each book
-- BookReviewCounts stores the total number of positive and non positive reviews for each book
-- Return books that have more positive reviews than non positive reviews


-- Query 4

WITH copyfromreview AS (
	SELECT review.book_id AS book_id, review.customer_id, loan.copy_id AS copy_id, bookcopy.date AS date, review.score AS score
	FROM review JOIN loan ON review.customer_id = loan.customer_id AND loan.copy_id IN (SELECT bookcopy.id   -- ensure the customer reviewing the book is the same as the customer loaning the copy AND that the copy loaned is a copy of the book reviewed
																						FROM bookcopy
																						WHERE review.book_id = bookcopy.book_id)
	AND loan.since <= review.when  -- ensure the copy was loaned before the review was made
	JOIN bookcopy ON loan.copy_id = bookcopy.id  -- join BookCopy so that we can order by copy date
	ORDER BY bookcopy.date  -- order the output from oldest to newest copies
),
averagescores AS (
	SELECT copyfromreview.book_id AS book_id, copyfromreview.copy_id AS copy_id, copyfromreview.date, AVG(copyfromreview.score) AS average_score
	FROM copyfromreview
	GROUP BY copyfromreview.book_id, copyfromreview.copy_id, copyfromreview.date
),
bookswithcopyhavingloweravgthanprecedingcopy AS (
	SELECT A.book_id AS book_id
	FROM averagescores AS A CROSS JOIN averagescores AS B
	WHERE A.book_id = B.book_id AND A.copy_id != B.copy_id AND A.date > B.date AND A.average_score < B.average_score
)
SELECT DISTINCT averagescores.book_id
FROM averagescores
LEFT JOIN bookswithcopyhavingloweravgthanprecedingcopy AS C ON averagescores.book_id = C.book_id  -- left join to keep all records in AverageScores
WHERE C.book_id IS NULL;  -- filter out books that are not in BooksWithCopyHavingLowerAvgThanPrecedingCopy

-- Clarifications:
-- CopyFromReview: Matches the review to the copy of the book in the review (to know which copy has been reviewed). Order by copy date (oldest to newest).
-- AverageScores: Group CopyFromReview by copy and calculate the average score
-- BooksWithCopyHavingLowerAvgThanPrecedingCopy: Cross product of two AverageScores's (AxB) to return A.book_id where A.book_id = B.book_id, A.copy != B.copy, A.date > B.date, and A.avg_score < B.avg_score
-- BooksWithCopyHavingLowerAvgThanPrecedingCopy gets all books which have a copy where that copy has a lower average score than a preceding copy
-- Return book id that are in AverageScores but not in BooksWithCopyHavingLowerAvgThanPrecedingCopy













