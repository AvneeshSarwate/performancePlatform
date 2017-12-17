open -a SuperCollider.app liveCodingSampler/allinone.scd && open -a Max.app liveCodingSampler/multisample.maxpat 

sleep 1

PYTHONJUPYTERPATH=/Library/Frameworks/Python.framework/Versions/2.7/bin/jupyter

if [ -f "$PYTHONJUPYTERPATH" ] ; then
	/Library/Frameworks/Python.framework/Versions/2.7/bin/jupyter notebook liveCodingSampler/livecodeSampling.ipynb
fi

BINJUPYTERPATH=/usr/local/bin/jupyter

if [ -f "$BINJUPYTERPATH" ] ; then
	/usr/local/bin/jupyter notebook liveCodingSampler/livecodeSampling.ipynb
fi







# PYTHONJUPYTERPATH='/Library/Frameworks/Python.framework/Versions/2.7/bin/jupyter'
# if [ -f "$PYTHONJUPYTERPATH" ] ; then 
# 	echo "PYTHON VERSION"
# else
# 	echo "NO PYTHON"
# fi

# BINJUPYTERPATH='/usr/local/bin/jupyter'
# if [ -f "$BINJUPYTERPATH" ] ; then
# 	echo "BIN VERSION"
# else
# 	echo "NO BIN"
# fi
