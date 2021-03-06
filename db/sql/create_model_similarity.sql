DROP TABLE IF EXISTS model_similarity;
CREATE TABLE model_similarity (
        id      	int NOT NULL PRIMARY KEY AUTO_INCREMENT,
        model_id_a     	int NOT NULL,
        model_id_b     	int NOT NULL,
	gene_score     	int NOT NULL,
	INDEX ms1 (model_id_a),	
	INDEX ms2 (model_id_b),
	UNIQUE INDEX ms3 (model_id_a, model_id_b),
	FOREIGN KEY (model_id_a) REFERENCES model(id),
	FOREIGN KEY (model_id_b) REFERENCES model(id)
);
