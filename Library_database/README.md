# Introduction

A small library holds information on their customers, on the books they have, and on any books that are
loaned out to customers. The relational schema for this library consists of the following relations (SQL
tables):

▶ **Customer(*id, name, city*)**  
Each customer has a unique identifier, a name, and a city in which they live.

▶ **Book(*id, publisher, title*)**  
Each book has a unique identifier, a publisher, and a title.

▶ **BookCopy(*id, book_id, date*)**  
Each physical copy of a book has a unique identifier, refers to a book in **Book** (via *book_id*), and has a
date of purchase.

▶ **Loan(*copy_id, customer_id, since, returned*)**  
Each physical copy of a book (identified by *copy_id*, which refers to **BookCopy**) can be loaned by a
customer of the library (identified by *customer_id*, which refers to **Customer**) since some date *since*. A
customer can loan a book multiple times, e.g., when previous copies are already returned (in which
case **returned** is true).

▶ **Review(*book_id, customer_id, when, score*)**  
Each customer (identified by *customer_id*, which refers to **Customer**) can review books (identified by
*book_id*, which refers to **Book**) by assigning a score (*score*) to the book.


## The Queries in `Script.sql`

### Query 1: **Summary of books**

Returns a summary of each book. So for each book identifier *id*, returns a row *(id, ncopies, nloans, newest)*.

---

### Query 2: **Good advice**

Returns pairs *(customer_id, book_id)* such that the customer with identifier *customer_id* might be interested in the book with identifier *book_id*.

A customer C might be interested in reading a book B if

▶ customer C did not read book B;  
▶ there exists another customer D that read all books read by customer C; and  
▶ customer D did read B.

---

### Query 3: **Well-received books**

Returns the identifiers of all books that have more positive reviews than non-positive reviews.

Consider a review *(b, c, w, s)* ∈ **Review**. This review is **positive** if the score *s* is strictly higher than the average score of all reviews by customer *c* before this review (hence, with a timestamp before *w*). The first review of a customer is considered **neutral**.

---

### Query 4: **Book-age bias**

Returns identifiers of books such that each copy has a higher average score than **all** preceding copies.
