# TODO: FSKAT functions using Identit working correlation, small sample adjustment based on perturbation
# Replace the pervious function file: Rfuns_FSKAT_rare_pertu.R
# Author: Xuefeng Wang
###############################################################################


##null fit function: estimate aplha.hat and delta.hat
fit_FSKAT_IC<-function(y,XC,FID){
	#y:phenotype
	#XC:covaraite matrix, including PC and intercept !
	#FID: family ID, not used if indentity working correlation
	
	#alpha<-t(t(c(-1,rep(1,(ncol(XC)-1))))) #initial values
	alpha<-summary(glm(y~XC[,-1],family=binomial("logit")))$coeff[,1]
	#OR use glm to get initial values	
	#if (class(FID)=="factor"){FID=as.character(FID)}
	#n<-length(unique(FID)) # family number
	#R1<-matrix(0.5,ncol=4,nrow=4); diag(R1)=1; R1[1,2]=R1[2,1]=0 # 2*Kinship matrix
	#R1<-diag(4)
	
	diff1<-10
	i<-0
	while (diff1>10e-6){
		
		i<-i+1
		
		#Fisher scoring
		mu<- plogis( XC %*% alpha)
		mu=as.vector(mu)
		#D=diag((mu)*(1-mu))%*%X
		V=diag((mu)*(1-mu)) #V=sqrt(A)%*%(R)%*%sqrt(A) 
		U=t(XC)%*%t(t((y-mu)))    #U=t(D)%*%solve(V)%*%t(t((y-mu)))
		I=t(XC)%*%V%*%XC	 	#I<-t(D)%*%solve(V)%*%D
		
		alpha.new<-alpha+solve(I)%*%U
		diff1 <- max(abs(alpha.new-alpha))
		alpha<-alpha.new
		
#		#Method of moments
#		mu.new<-plogis(X%*%alpha)
#		r.hat<-(y-mu.new)/sqrt((mu.new*(1-mu.new)))    #Pearson residual
#		
#		mydata<-data.frame(FID=rep(1:n,each=4),r.hat=r.hat)
#		
#		result<-Reduce("+",lapply(split(mydata,mydata$FID),function (adata) {
#			ri<-adata[,2]
#			RI<-tcrossprod(ri)
#			mynu<-sum(RI[upper.tri(RI)])
#			myde<-sum(R1[upper.tri(R1)])
#			return(c(mynu,myde))
#		}))
#		d.new<-result[1]/result[2]
#		diff2 <- abs(d.new - d)		
#		d<-d.new
	}	
	return(list(alpha,i))
}

##score test
## gskat_seq(y,XC,Z,ID,w_a=1,w_b=1, pw="Norm")
## gskat_seq(y,XC,Z,ID,w_a=1,w_b=1, pw="Rade")
## gskat_seq(y,XC,Z,ID,w_a=1,w_b=5, pw="Norm")
## gskat_seq(y,XC,Z,ID,w_a=1,w_b=5, pw="Rade")
## gskat_seq(y,XC,Z,ID,pw="Rade")
## gskat_seq(y,XC,Z,ID,pw="Rade",sW=FALSE)
## gskat_seq(y,XC,Z,ID,pw="Norm")
## gskat_seq(y,XC,Z,ID,pw="Norm",sW=FALSE)

gskat_seq<-function(y,XC,Z,ID,impute.method="fixed",SNP.weights=NULL,w_a=1,w_b=25,resampling=TRUE,pw="Rade",Uc=TRUE,sW=FALSE,np=10000) {
	##VERSION: 7/6/2013 
	#CHANGE: Default: np=10000; sW=FALSE; Uc=TRUE
	#CHANGE: W<- not squared any more
	##VERSION: 7/16/2014
	#CHANGE: ADD fixed imputation method
	#CHANGE: better intercept attach function
	##VERSION 7/22/2014
	#CHANGE: Add resampling control
	#CHANGE: enable customized weights
	
	#w_a=1;w_b=25; pw="Rade"; Uc=FALSE
	maf<-apply(Z,2,function(x){sum(x,na.rm=T)/((length(x)-sum(is.na(x)))*2)} )#cacluate before center
	if(impute.method=="fixed") Z<-apply(Z,2,function(x){x[is.na(x)]=mean(x,na.rm=TRUE);return(x)}) #mean values imputation
	
	Z<-scale(Z,scale=F) #Z need to be centered !!!
	#require("CompQuadForm")	
	#require(e1071)
	#
	if (sum(XC[,1]!=1)!=0) {XC=cbind(1,data.matrix(XC))} #now with intercept, assume all nonvariants removed
	Z<-data.matrix(Z)	#Z is the combined genotype, must be matrix format
	y<-as.vector(y);FID<-as.factor(ID$FID)
	##sort according to FID	
	FID.old<-FID
	FID<-FID[order(FID.old)]; y<-y[order(FID.old)];XC<-XC[order(FID.old),];Z<-data.matrix(Z[order(FID.old),]) #!!
	ID<-ID[order(FID.old),]
	p=ncol(Z); q=ncol(XC)-1
	#
	
	#weight W
	#w_a=1; w_b=25
	if (is.null(SNP.weights)){
		#w_a=1; w_b=25
		if (length(maf)==1){W=1} else {
			#W<-diag((dbeta(maf,w_a, w_b))^2) } #beta density
			W<-diag(dbeta(maf,w_a, w_b)) } #beta density
		if (sW==TRUE) {W<-W/max(W)} 
		#W<-diag(length(maf))
	} else {
		W<-diag(SNP.weights)
	}
	
	#
	null<-fit_FSKAT_IC(y,XC,FID)
	alpha<-null[[1]]
	#
	mu<-as.vector(plogis(XC%*%alpha))
	U=t(Z)%*%t(t((y-mu)))
	#V=null[[4]] 
	V=diag((mu)*(1-mu))
	Covy<-tcrossprod(y-mu)
	#Covy[((row(Covy)-1)%/%4+1)!=((col(Covy)-1)%/%4+1)]=0  #for same family strut of 4 members
	Covy=Covy*blockMatrixDiagonal(lapply(split(FID,FID),function(alist){matrix(1,length(alist),length(alist))}))
	
	XZ<-cbind(XC,Z)
	B<-t(XZ)%*%Covy%*%XZ  #Bi<-t(Di)%*%iVi%*%Covyi%*%iVi%*%Di
	A<-t(XZ)%*%V%*%XZ  #AAi<-t(Di)%*%iVi%*%Di 
	
	Azx<-A[(q+1+1):ncol(A),1:(q+1)]
	Axx<-A[1:(q+1),1:(q+1)]
	C<-cbind(-Azx%*%solve(Axx),diag(p))
	
	TS<-t(U)%*%W%*%U
	
	Bsqrt=mysqrt(B)
	BC<-Bsqrt%*%t(C)%*%W%*%C%*%Bsqrt	
	Lamda<-eigen(BC,only.values=T)$values
	results<-davies(TS,Lamda,rep(1, length(Lamda)))
	results
	
	if (resampling==TRUE | results$Qq>1 | results$ifault==1){
		#perturbation
		#mom R or Identity
		a=diag((mu)*(1-mu))
		R<-diag(dim(a)[1])
		iV<-solve(sqrt(a)%*%(R)%*%sqrt(a))	
		#U_mat=t(Z)%*%a%*%iV%*%t(t((y-mu)))
		
		y_mu_t=t(t(y-mu)) 
		ZaV<-t(Z)%*%a%*%iV
		ni<-do.call(c,lapply(split(ID$FID,ID$FID),function(x){length(x)}))
		Ub.boot<-matrix(ncol=np,nrow=nrow(U))
		n=length(unique(ID$FID))
		
		if (pw=="Norm") {
			Ub.boot<-apply(Ub.boot,2, function (x) {
						res.pert<-y_mu_t* rep(rnorm(n), ni) #Normal perturbation
						return(ZaV%*%res.pert)
					})		
		} else if (pw=="Rade") {
			Ub.boot<-apply(Ub.boot,2, function (x) {
						res.pert<-y_mu_t* rep(sample(c(1,-1),n,replace=T), ni)  #Rademacher distribution
						return(ZaV%*%res.pert)
					})		
		}
		
		if (Uc==TRUE){Ub.boot<-apply(Ub.boot,1,scale, scale = FALSE)} else if (length(maf)==1) {
			Ub.boot<-t(t(Ub.boot))} else {
			Ub.boot<-t(Ub.boot)} #
		Ts_boot<-apply(Ub.boot,1,function (x) {t(x)%*%W%*%x })
		
		mean(Ts_boot)
		var(Ts_boot); var_theory=2*(sum(diag(B%*%t(C)%*%W%*%C%*%B%*%t(C)%*%W%*%C)))
		df=12/kurtosis(Ts_boot)
		if (df<0) {df=100}
		
		mu_Ts<- sum(diag(B%*%t(C)%*%W%*%C)) #trace(BC)  # Bsqrt=mysqrt(B); BC<-Bsqrt%*%t(C)%*%C%*%Bsqrt
		#mu_Ts
		if (df<0) {pval=NA} else {
			pval=1-pchisq((TS-mu_Ts)*sqrt(2*df)/sqrt(var(Ts_boot))+df, df=df)}
		#pval
	} else {
		Ts_boot=mu_Ts=var_theory=df=pval=NA
	}
	#return(c(length(maf),sum(maf>0.05),results$Qq,results$ifault,mean(Ts_boot),mu_Ts, var(Ts_boot), var_theory ,df,pval ))
	p1<-results$Qq
	p2<-pval
	return(c(p1,p2))
}



###Misc functions below###

# builds a block matrix whose diagonals are the square matrices provided.
# blockMatrix<-blockMatrixDiagonal(m1,m2,m2,m1)
# or blockMatrix<-blockMatrixDiagonal(list(m1,m2,m2,m1))
#T=blockMatrixDiagonal
blockMatrixDiagonal<-function(...){  
	matrixList<-list(...)
	if(is.list(matrixList[[1]])) matrixList<-matrixList[[1]]
	
	dimensions<-sapply(matrixList,FUN=function(x) dim(x)[1])
	finalDimension<-sum(dimensions)
	finalMatrix<-matrix(0,nrow=finalDimension,ncol=finalDimension)
	index<-1
	for(k in 1:length(dimensions)){
		finalMatrix[index:(index+dimensions[k]-1),index:(index+dimensions[k]-1)]<-matrixList[[k]]
		index<-index+dimensions[k]
	}
	finalMatrix
} 
##


#square root of a matrix
mysqrt<-function (V) {
	#V=B
	V.eig<-eigen(V)
	V.eigvalues<-V.eig$values
	V.eigvalues[-1e-8<V.eigvalues & V.eigvalues<0]=0
	V.sqrt=V.eig$vectors %*% diag(sqrt(V.eigvalues)) %*% solve(V.eig$vectors)
	return(V.sqrt)
}


