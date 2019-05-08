clear;
% -------------------------------------------------------------------------
%% choosing the dataset
dataset = 'ExtendedYaleB';
% AR_DAT
% ExtendedYaleB
% -------------------------------------------------------------------------
%% specify corruption type
corruption_type = 'RC';
% RC: random_corruption
% BO: block_occlusion
% -------------------------------------------------------------------------
%% choosing classification methods
% ClassificationMethod = 'NSC';
% ClassificationMethod = 'SRC'; addpath(genpath('C:\Users\csjunxu\Desktop\Classification\l1_ls_matlab'));
% ClassificationMethod = 'CRC';
% ClassificationMethod = 'CROC';
ClassificationMethod = 'ProCRC'; addpath(genpath('C:\Users\csjunxu\Desktop\Classification\ProCRC'));

% ClassificationMethod = 'NNLSR' ; % non-negative LSR
% ClassificationMethod = 'NPLSR' ; % non-positive LSR
% ClassificationMethod = 'ANNLSR' ; % affine and non-negative LSR
% ClassificationMethod = 'ANPLSR' ; % affine and non-positive LSR
% ClassificationMethod = 'DANNLSR' ; % deformable, affine and non-negative LSR
% ClassificationMethod = 'DANPLSR' ; % deformable, affine and non-positive LSR
% -------------------------------------------------------------------------
%% number of repeations
if strcmp(dataset, 'ExtendedYaleB') == 1
    nExperiment = 10;
elseif strcmp(dataset, 'AR_DAT') == 1
    nExperiment = 1;
end
% -------------------------------------------------------------------------
%% directory to save the results
writefilepath  = ['C:/Users/csjunxu/Desktop/Classification/Results/' dataset '/'];
if ~isdir(writefilepath)
    mkdir(writefilepath);
end
% -------------------------------------------------------------------------
%% PCA dimension
for nDim = [500]
    Par.nDim = nDim;
    %-------------------------------------------------------------------------
    %% tuning the parameters
    for s = [1]
        Par.s = s;
        for maxIter = [5]
            Par.maxIter  = maxIter;
            for rho = [-2:1:3]
                Par.rho = 10^(-rho);
                for ratio = [0 0.1 0.2 0.4 0.6]
                    for lambda = [0]
                        Par.lambda = lambda*10^(-1);
                        accuracy = zeros(nExperiment, 1) ;
                        for n = 1:nExperiment
                            %--------------------------------------------------------------------------
                            %% data loading
                            if strcmp(dataset, 'AR_DAT') == 1
                                load(['C:/Users/csjunxu/Desktop/Classification/Dataset/AR_DAT']);
                                nClass        =   max(trainlabels); % the number of classes in the subset of AR database
                                % Par.nDim = 54 120 300  the eigenfaces dimension
                                Tr_DAT   =   double(NewTrain_DAT(:,trainlabels<=nClass));
                                trls     =   trainlabels(trainlabels<=nClass);
                                Tt_DAT   =   double(NewTest_DAT(:,testlabels<=nClass));
                                ttls     =   testlabels(testlabels<=nClass);
                                clear NewTest_DAT NewTrain_DAT testlabels trainlabels
                            elseif strcmp(dataset, 'ExtendedYaleB') == 1
                                % Par.nDim = 84 150 300 the eigenfaces dimension
                                load(['C:/Users/csjunxu/Desktop/Classification/Dataset/YaleBCrop025']);
                                % randomly select half of the samples as training data;
                                [dim, nSample, nClass] = size(Y);
                                % nClass is the number of classes in the subset of AR database
                                Tr_DAT = [];
                                Tt_DAT = [];
                                trls = [];
                                ttls = [];
                                for i=1:nClass
                                    rng(n);
                                    RanCi = randperm(nSample);
                                    nTr = floor(length(RanCi)/2);
                                    nTt = length(RanCi) - nTr;
                                    Tr_DAT   =   [Tr_DAT double(Y(:, RanCi(1:nTr), i))];
                                    trls     =   [trls i*ones(1, nTr)];
                                    Tt_DAT   =   [Tt_DAT double(Y(:, RanCi(nTr+1:end), i))];
                                    ttls     =   [ttls i*ones(1, nTt)];
                                end
                                clear Y I Ind s
                            end
                            if ratio~=0
                                addpath(genpath('C:\Users\csjunxu\Desktop\Classification\ProCRC'));
                                %--------------------------------------------------------------------------
                                %% corruption settings
                                if strcmp(dataset, 'AR_DAT') == 1
                                    imh = 60; imw = 43;
                                elseif strcmp(dataset, 'ExtendedYaleB') == 1
                                    imh = 48; imw = 42;
                                end
                                switch corruption_type
                                    case 'RC'
                                        cor_ratio = ratio;
                                        [~, samp_num] = size(Tt_DAT);
                                        for i_t = 1 : samp_num
                                            xt = Tt_DAT(:, i_t);
                                            xt = reshape(xt, [imh, imw]);
                                            xc = Random_Pixel_Crop(uint8(255 * xt), cor_ratio);
                                            Tt_DAT(:, i_t) = double(xc(:))/255;
                                        end
                                    case 'BO'
                                        cor_ratio = ratio;
                                        height  = floor(sqrt(imh * imw * cor_ratio));
                                        width   = height;
                                        [~, samp_num] = size(Tt_DAT);
                                        r_h = round(rand(1, samp_num) * (imh - height -1)) + 1;
                                        r_w = round(rand(1, samp_num) * (imw - width -1)) + 1;
                                        for i_t = 1 : samp_num
                                            xt = Tt_DAT(:, i_t);
                                            xt = reshape(xt, [imh, imw]);
                                            xc = Random_Block_Occlu(uint8(255 * xt), r_h(i_t), r_w(i_t), height, width);
                                            Tt_DAT(:, i_t) = double(xc(:))/255;
                                        end
                                    otherwise
                                        error(['\nUnknown corruption type: ' corruption_type]);
                                end
                            end
                            %--------------------------------------------------------------------------
                            %% eigenface extracting
                            if Par.nDim ==0
                                tr_dat  =  Tr_DAT./( repmat(sqrt(sum(Tr_DAT.*Tr_DAT)), [size(Tr_DAT,1), 1]) );
                                tt_dat  =  Tt_DAT./( repmat(sqrt(sum(Tt_DAT.*Tt_DAT)), [size(Tt_DAT,1), 1]) );
                            else
                                [disc_set,disc_value,Mean_Image]  =  Eigenface_f(Tr_DAT,Par.nDim);
                                tr_dat  =  disc_set'*Tr_DAT;
                                tt_dat  =  disc_set'*Tt_DAT;
                                tr_dat  =  tr_dat./( repmat(sqrt(sum(tr_dat.*tr_dat)), [Par.nDim,1]) );
                                tt_dat  =  tt_dat./( repmat(sqrt(sum(tt_dat.*tt_dat)), [Par.nDim,1]) );
                            end
                            
                            %-------------------------------------------------------------------------
                            %% testing
                            ID = [];
                            for indTest = 1:size(tt_dat,2)
                                switch ClassificationMethod
                                    case 'SRC'
                                        rel_tol = 0.01;     % relative target duality gap
                                        [coef, status]=l1_ls(tr_dat, tt_dat(:,indTest), Par.lambda, rel_tol);
                                    case 'CRC'
                                        Par.lambda = .001 * size(Tr_DAT,2)/700;
                                        %projection matrix computing
                                        Proj_M = (tr_dat'*tr_dat+Par.lambda*eye(size(tr_dat,2)))\tr_dat';
                                        coef         =  Proj_M*tt_dat(:,indTest);
                                    case 'ProCRC'
                                        params.dataset_name      =      'Extended Yale B';
                                        params.model_type        =      'R-ProCRC';
                                        params.gamma             =      [1e-2];
                                        params.lambda            =      [1e-0];
                                        params.class_num         =      max(trls);
                                        data.tr_descr = tr_dat;
                                        data.tt_descr = tt_dat(:,indTest);
                                        data.tr_label = trls;
                                        data.tt_label = ttls;
                                        coef = ProCRC(data, params);
                                    case 'NNLSR'                   % non-negative
                                        coef = NNLSR( tt_dat(:,indTest), tr_dat, Par );
                                    case 'NPLSR'               % non-positive
                                        coef = NPLSR( tt_dat(:,indTest), tr_dat, Par );
                                    case 'ANNLSR'                 % affine, non-negative, sum to 1
                                        coef = ANNLSR( tt_dat(:,indTest), tr_dat, Par );
                                    case 'ANPLSR'             % affine, non-negative, sum to -1
                                        coef = ANPLSR( tt_dat(:,indTest), tr_dat, Par );
                                    case 'DANNLSR'                 % affine, non-negative, sum to a scalar s
                                        coef = DANNLSR( tt_dat(:,indTest), tr_dat, Par );
                                    case 'DANPLSR'             % affine, non-positive, sum to a scalar -s
                                        coef = DANPLSR( tt_dat(:,indTest), tr_dat, Par );
                                end
                                % -------------------------------------------------------------------------
                                %% assign the class  index
                                for ci = 1:max(trls)
                                    coef_c   =  coef(trls==ci);
                                    Dc       =  tr_dat(:,trls==ci);
                                    error(ci) = norm(tt_dat(:,indTest)-Dc*coef_c,2)^2/sum(coef_c.*coef_c);
                                end
                                index      =  find(error==min(error));
                                id         =  index(1);
                                ID      =   [ID id];
                            end
                            cornum      =   sum(ID==ttls);
                            accuracy(n, 1)         =   [cornum/length(ttls)]; % recognition rate
                            fprintf(['Accuracy is ' num2str(accuracy(n, 1)) '.\n']);
                        end
                        % -------------------------------------------------------------------------
                        %% save the results
                        avgacc = mean(accuracy);
                        fprintf(['Mean Accuracy is ' num2str(avgacc) '.\n']);
                        if strcmp(ClassificationMethod, 'SRC') == 1 || strcmp(ClassificationMethod, 'CRC') == 1
                            matname = sprintf([writefilepath dataset '_' ClassificationMethod '_DR' num2str(Par.nDim) '_Ctype' corruption_type '_ratio' num2str(ratio) '_lambda' num2str(Par.lambda) '.mat']);
                            save(matname, 'accuracy', 'avgacc');
                        else
                            matname = sprintf([writefilepath dataset '_' ClassificationMethod '_DR' num2str(Par.nDim) '_Ctype' corruption_type '_ratio' num2str(ratio) '_scale' num2str(Par.s) '_maxIter' num2str(Par.maxIter) '_rho' num2str(Par.rho) '_lambda' num2str(Par.lambda) '.mat']);
                            save(matname,'accuracy', 'avgacc');
                        end
                    end
                end
            end
        end
    end
end